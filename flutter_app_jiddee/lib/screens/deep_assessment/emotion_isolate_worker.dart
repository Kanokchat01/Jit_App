import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class LoadMsg {
  final Uint8List modelBytes;
  final SendPort replyTo;
  LoadMsg(this.modelBytes, this.replyTo);
}

class PredictMsg {
  final Map<String, dynamic> imageMap;
  final Map<String, double>? faceBox;
  final bool useFaceDetector;
  final SendPort replyTo;
  final double objTh;
  final double clsTh;
  final bool debug;

  PredictMsg({
    required this.imageMap,
    required this.faceBox,
    required this.useFaceDetector,
    required this.replyTo,
    required this.objTh,
    required this.clsTh,
    this.debug = false,
  });
}

late Interpreter _interpreter;
late List<int> _outShape;
late dynamic _output;
bool _ready = false;

const List<String> _labels = ['angry', 'fear', 'happy', 'neutral', 'sad'];

double _sigmoid(double x) => 1.0 / (1.0 + exp(-x));

dynamic _allocOutput(List<int> shape) {
  // รองรับเฉพาะ [1, A, B] หรือ [1, A, B, ...] -> เอา 3 มิติแรก
  if (shape.length < 3) {
    throw Exception('Unsupported output shape: $shape');
  }
  final a = shape[0], b = shape[1], c = shape[2];
  return List.generate(a, (_) => List.generate(b, (_) => List.filled(c, 0.0)));
}

bool _needsSigmoidCHW(List<List<double>> feats) {
  // If logits exceed 1.2 or are below -0.2, they are likely not probablities.
  final n = feats[0].length;
  final limit = min(20, n);
  final channels = feats.length;
  for (int i = 0; i < limit; i++) {
    for (int c = 4; c < channels; c++) {
      if (feats[c][i] > 1.2 || feats[c][i] < -0.2) return true;
    }
  }
  return false;
}

bool _needsSigmoidHWC(List<List<double>> feats) {
  final n = feats.length;
  final limit = min(20, n);
  final channels = feats[0].length;
  for (int i = 0; i < limit; i++) {
    for (int c = 4; c < channels; c++) {
      if (feats[i][c] > 1.2 || feats[i][c] < -0.2) return true;
    }
  }
  return false;
}

/// decode แบบ “robust” รองรับ YOLOv8 Format (ไม่มี Objectness แยก): Boundingbox(4) + Classes(...)
Map<String, dynamic>? _decodeBest(dynamic output, List<int> shape, double objTh, double clsTh, {bool debug = false}) {
  final b = shape[1];
  final c = shape[2];

  // CHW: [1, channels, 8400]
  // HWC: [1, 8400, channels]
  final isCHW = (c >= 1000 && b <= 64);
  final isHWC = (b >= 1000 && c <= 64);

  double bestScore = -1;
  double bestObj = 1.0; // YOLOv8 implicit
  double bestCls = 0;
  int bestClass = -1;
  int bestAnchorIdx = 0; // ✅ track best anchor เพื่อดึง allScores

  double maxObjSeen = 1.0;
  double maxClsSeen = -1e9;
  bool useSigmoid = true;
  bool belowThreshold = false;

  final int clsStart = 4;

  if (isCHW) {
    final feats = output[0] as List<List<double>>; // [channels][N]
    final channels = feats.length;
    final n = feats[0].length;
    final clsCount = max(0, channels - clsStart).clamp(0, _labels.length);

    useSigmoid = _needsSigmoidCHW(feats);

    for (int i = 0; i < n; i++) {
      double bestClsLocal = -1;
      int clsIdx = -1;

      for (int k = 0; k < clsCount; k++) {
        double p = feats[clsStart + k][i];
        if (useSigmoid) p = _sigmoid(p);
        if (p > maxClsSeen) maxClsSeen = p;
        if (p > bestClsLocal) {
          bestClsLocal = p;
          clsIdx = k;
        }
      }

      if (bestClsLocal > bestScore) {
        bestScore = bestClsLocal;
        bestCls = bestClsLocal;
        bestClass = clsIdx;
        bestAnchorIdx = i; // ✅ จำ anchor index
      }
    }

    if (bestCls < clsTh) belowThreshold = true;

  } else if (isHWC) {
    final feats = output[0] as List<List<double>>; // [N][channels]
    final n = feats.length;
    final channels = feats[0].length;
    final clsCount = max(0, channels - clsStart).clamp(0, _labels.length);

    useSigmoid = _needsSigmoidHWC(feats);

    for (int i = 0; i < n; i++) {
      if (feats[i].length < clsStart + 1) continue;

      double bestClsLocal = -1;
      int clsIdx = -1;

      for (int k = 0; k < clsCount; k++) {
        double p = feats[i][clsStart + k];
        if (useSigmoid) p = _sigmoid(p);
        if (p > maxClsSeen) maxClsSeen = p;
        if (p > bestClsLocal) {
          bestClsLocal = p;
          clsIdx = k;
        }
      }

      if (bestClsLocal > bestScore) {
        bestScore = bestClsLocal;
        bestCls = bestClsLocal;
        bestClass = clsIdx;
        bestAnchorIdx = i; // ✅ จำ anchor index
      }
    }

    if (bestCls < clsTh) belowThreshold = true;

  } else {
    // shape ไม่เข้า heuristic -> ส่ง debug กลับไปให้ดู
    return {
      'error': 'unsupported_shape',
      'outShape': shape.toString(),
    };
  }

  // map class ให้ไม่เกิน labels (ถ้าโมเดลมีมากกว่า 5 คลาส จะ clamp)
  if (bestClass < 0) {
    return {
      'error': 'no_class',
      'outShape': shape.toString(),
    };
  }
  final safeIdx = bestClass.clamp(0, _labels.length - 1);

  // ✅ ดึง allScores จาก best anchor (ให้ aggregator ใช้)
  final Map<String, double> allScores = {};
  if (isCHW) {
    final feats = output[0] as List<List<double>>;
    final channels = feats.length;
    final clsCount = max(0, channels - clsStart).clamp(0, _labels.length);
    for (int k = 0; k < clsCount; k++) {
      double p = feats[clsStart + k][bestAnchorIdx];
      if (useSigmoid) p = _sigmoid(p);
      allScores[_labels[k]] = p;
    }
  } else if (isHWC) {
    final feats = output[0] as List<List<double>>;
    final channels = feats[0].length;
    final clsCount = max(0, channels - clsStart).clamp(0, _labels.length);
    for (int k = 0; k < clsCount; k++) {
      double p = feats[bestAnchorIdx][clsStart + k];
      if (useSigmoid) p = _sigmoid(p);
      allScores[_labels[k]] = p;
    }
  }

  final resp = <String, dynamic>{
    'classIndex': safeIdx,
    'label': _labels[safeIdx],
    'confidence': bestScore.isFinite ? bestScore : 0.0,
    'obj': bestObj,
    'cls': bestCls,
    'belowThreshold': belowThreshold,
    'allScores': allScores, // ✅ ทุก class score
  };

  if (debug) {
    resp['outShape'] = shape;
    resp['useSigmoid'] = useSigmoid;
    resp['maxObjRaw'] = maxObjSeen;
    resp['maxClsRaw'] = maxClsSeen;
  }

  return resp;
}

void emotionIsolateEntry(SendPort mainSendPort) async {
  final port = ReceivePort();
  mainSendPort.send(port.sendPort);

  await for (final msg in port) {
    if (msg is LoadMsg) {
      try {
        final options = InterpreterOptions()..threads = 4;
        _interpreter = Interpreter.fromBuffer(msg.modelBytes, options: options);
        _outShape = _interpreter.getOutputTensor(0).shape;
        _output = _allocOutput(_outShape);
        _ready = true;

        // ignore: avoid_print
        print('EMO model loaded. outShape=$_outShape');

        msg.replyTo.send(true);
      } catch (e) {
        _ready = false;
        msg.replyTo.send(false);
      }
    } else if (msg is PredictMsg) {
      if (!_ready) {
        msg.replyTo.send(null);
        continue;
      }

      try {
        // ✅ Step 1: แปลง YUV → RGB
        final img.Image? rgbRaw = _convertMapToImage(
          msg.imageMap,
          swapUV: true,
          downSample: 1,
        );

        if (rgbRaw == null) {
          msg.replyTo.send({'error': 'rgbFull=null'});
          continue;
        }

        // ✅ Step 2: หมุนภาพให้ตั้งตรง (สำคัญมาก! ไม่งั้นหน้าตะแคง model จำไม่ได้)
        final img.Image rgbUpright = _rotateToUpright(rgbRaw, msg.imageMap);

        // ✅ Step 3: Crop หน้า (ตอนนี้ coordinates ตรงกับ face box จาก ML Kit แล้ว)
        img.Image? crop = _selectCrop(rgbUpright, msg.faceBox, msg.useFaceDetector);
        if (crop == null) {
          msg.replyTo.send({'error': 'no-face'});
          continue;
        }

        // ✅ Step 4: Flip horizontal สำหรับกล้องหน้า (ทำหลัง crop เพื่อความเร็ว)
        crop = _applyMirror(crop, msg.imageMap);

        final resized = img.copyResize(crop, width: 640, height: 640, interpolation: img.Interpolation.linear);
        final inputBuffer = _imageToFloat32NHWC(resized);
        final inputTensor = inputBuffer.reshape([1, 640, 640, 3]);

        _interpreter.run(inputTensor, _output);

        final decoded = _decodeBest(
          _output,
          _outShape,
          msg.objTh,
          msg.clsTh,
          debug: msg.debug,
        );

        msg.replyTo.send(decoded);
      } catch (e) {
        msg.replyTo.send({'error': e.toString()});
      }
    }
  }
}

img.Image? _convertMapToImage(
  Map<String, dynamic> imageMap, {
  bool swapUV = false,
  int downSample = 1,
}) {
  try {
    final int srcW = imageMap['width'];
    final int srcH = imageMap['height'];
    final String formatGroup = imageMap['formatGroup'];
    final List planes = imageMap['planes'];

    if (downSample < 1) downSample = 1;
    final int outW = srcW ~/ downSample;
    final int outH = srcH ~/ downSample;

    final out = img.Image(width: outW, height: outH);

    if (formatGroup == 'bgra8888') {
      final Uint8List bytes = planes[0]['bytes'];
      final int bytesPerRow = planes[0]['bytesPerRow'];
      final int bytesPerPixel = planes[0]['bytesPerPixel'] ?? 4;
      for (int y = 0, oy = 0; y < srcH; y += downSample, oy++) {
        int rowOffset = y * bytesPerRow;
        for (int x = 0, ox = 0; x < srcW; x += downSample, ox++) {
          int offset = rowOffset + x * bytesPerPixel;
          int b = bytes[offset];
          int g = bytes[offset + 1];
          int r = bytes[offset + 2];
          out.setPixelRgb(ox, oy, r, g, b);
        }
      }
    } else {
      final Uint8List bytesY = planes[0]['bytes'];
      final Uint8List bytesU = planes[1]['bytes'];
      final Uint8List bytesV = planes[2]['bytes'];

      final int yRowStride = planes[0]['bytesPerRow'];
      final int uvRowStride = planes[1]['bytesPerRow'];
      final int uvPixelStride = planes[1]['bytesPerPixel'] ?? 1;

      int oy = 0;
      for (int y = 0; y < srcH; y += downSample, oy++) {
        final int yRow = yRowStride * y;
        final int uvRow = uvRowStride * (y >> 1);

        int ox = 0;
        for (int x = 0; x < srcW; x += downSample, ox++) {
          final int yIndex = yRow + x;
          final int uvIndex = uvRow + (x >> 1) * uvPixelStride;

          final int Y = bytesY[yIndex] & 0xFF;

          int U = bytesU[uvIndex] & 0xFF;
          int V = bytesV[uvIndex] & 0xFF;

          if (swapUV) {
            final int tmp = U;
            U = V;
            V = tmp;
          }

          int C = Y - 16;
          if (C < 0) C = 0;

          final int D = U - 128;
          final int E = V - 128;

          int R = (298 * C + 409 * E + 128) >> 8;
          int G = (298 * C - 100 * D - 208 * E + 128) >> 8;
          int B = (298 * C + 516 * D + 128) >> 8;

          if (R < 0) R = 0;
          if (R > 255) R = 255;
          if (G < 0) G = 0;
          if (G > 255) G = 255;
          if (B < 0) B = 0;
          if (B > 255) B = 255;

          out.setPixelRgb(ox, oy, R, G, B);
        }
      }
    }

    return out;
  } catch (_) {
    return null;
  }
}

/// ✅ หมุนภาพให้ตั้งตรง ตาม sensorOrientation ของกล้อง
/// Android front camera ส่วนใหญ่ sensorOrientation=270
/// ถ้าไม่หมุน → หน้าจะตะแคง → model ทำนายผิดหมด!
img.Image _rotateToUpright(img.Image image, Map<String, dynamic> imageMap) {
  final int sensorOrientation = imageMap['sensorOrientation'] ?? 0;
  if (sensorOrientation == 0) return image;

  // img.copyRotate หมุนตาม angle ที่ระบุ
  return img.copyRotate(image, angle: sensorOrientation);
}

/// ✅ Flip horizontal สำหรับกล้องหน้า (mirror effect)
img.Image _applyMirror(img.Image image, Map<String, dynamic> imageMap) {
  final String lensDirection = imageMap['lensDirection'] ?? 'front';
  if (lensDirection == 'front') {
    return img.flipHorizontal(image);
  }
  return image;
}

img.Image? _selectCrop(img.Image full, Map<String, double>? faceBox, bool useFaceDetector) {
  if (!useFaceDetector) return _centerCrop(full);
  if (faceBox != null) return _cropByFaceBox(full, faceBox);
  return null;
}

img.Image? _cropByFaceBox(img.Image full, Map<String, double> box) {
  final w = full.width;
  final h = full.height;

  int x = box['left']!.round().clamp(0, w - 1);
  int y = box['top']!.round().clamp(0, h - 1);
  int cw = box['width']!.round().clamp(1, w - x);
  int ch = box['height']!.round().clamp(1, h - y);

  final pad = (0.18 * (cw < ch ? cw : ch)).round();
  x = (x - pad).clamp(0, w - 1);
  y = (y - pad).clamp(0, h - 1);
  cw = (cw + pad * 2).clamp(1, w - x);
  ch = (ch + pad * 2).clamp(1, h - y);

  if (cw < 32 || ch < 32) return null;
  return img.copyCrop(full, x: x, y: y, width: cw, height: ch);
}

img.Image? _centerCrop(img.Image full, {double area = 0.70}) {
  final w = full.width;
  final h = full.height;
  final side = (w < h ? w : h);
  final cropSide = (side * area).round();
  if (cropSide < 32) return null;

  final cx = (w / 2).round();
  final cy = (h / 2).round();

  final x = (cx - cropSide / 2).round().clamp(0, w - 1);
  final y = (cy - cropSide / 2).round().clamp(0, h - 1);
  final cw = cropSide.clamp(1, w - x);
  final ch = cropSide.clamp(1, h - y);

  if (cw <= 2 || ch <= 2) return null;
  return img.copyCrop(full, x: x, y: y, width: cw, height: ch);
}

Float32List _imageToFloat32NHWC(img.Image image) {
  final h = image.height;
  final w = image.width;
  final out = Float32List(1 * h * w * 3);

  int idx = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      out[idx++] = p.r / 255.0;
      out[idx++] = p.g / 255.0;
      out[idx++] = p.b / 255.0;
    }
  }
  return out;
}