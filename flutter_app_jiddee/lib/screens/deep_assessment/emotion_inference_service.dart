import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class EmotionPrediction {
  final String label;
  final double confidence;

  // debug
  final bool belowThreshold;
  final double obj;
  final double cls;
  final String outShape;
  final double maxObjRaw;
  final double maxClsRaw;
  final String? error;

  EmotionPrediction({
    required this.label,
    required this.confidence,
    required this.belowThreshold,
    required this.obj,
    required this.cls,
    required this.outShape,
    required this.maxObjRaw,
    required this.maxClsRaw,
    required this.error,
  });
}

class EmotionInferenceService {
  Interpreter? _interpreter;

  // ตาม metadata.yaml ของหนู
  static const List<String> labels = ['angry', 'fear', 'happy', 'neutral', 'sad'];

  final int everyNFrames;
  int _frameCount = 0;

  EmotionInferenceService({this.everyNFrames = 1});

  bool get isLoaded => _interpreter != null;

  Future<void> load() async {
    if (_interpreter != null) return;

    final modelData = await rootBundle.load('assets/models/emotion_model.tflite');
    final options = InterpreterOptions()..threads = 2;

    // ✅ tflite_flutter ^0.11.0 ใช้ options เป็น named parameter
    _interpreter = Interpreter.fromBuffer(
      modelData.buffer.asUint8List(),
      options: options,
    );
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// YOLO detect output ของหนู: [1, 9, 8400] (x,y,w,h + 5 class scores; no obj)
  Future<EmotionPrediction?> predictFromRgbImage(
    img.Image rgb, {
    required double objTh,
    required double clsTh,
    bool debug = false,
  }) async {
    try {
      if (_interpreter == null) return null;

      _frameCount++;
      if (everyNFrames > 1 && (_frameCount % everyNFrames != 0)) {
        return null;
      }

      // 1) resize to 640x640
      final resized = img.copyResize(rgb, width: 640, height: 640, interpolation: img.Interpolation.linear);

      // 2) to Float32 input [1,640,640,3] normalized 0..1
      final input = _imageToFloat32NHWC(resized);

      // 3) output buffer
      // output shape: [1,9,8400]
      final output = List.generate(1, (_) => List.generate(9, (_) => List.filled(8400, 0.0)));

      _interpreter!.run(input, output);

      // debug shape
      final outShape = '[1,9,8400]';

      // YOLO format (Ultralytics exported): often [1, 84, 8400] for COCO;
      // here 9 = 4 + 1 + 4? actually 5 classes => 4+1+5 =10 but metadata says nms:false, task:detect, 5 classes
      // In your log you showed shape [1,9,8400] so we parse as:
      // [x,y,w,h,obj, cls0,cls1,cls2,cls3]  (and maybe cls4 missing?) OR model exported with 4 classes?
      // But metadata says 5 classes. So to be safe we will read channels = 9 and use last 5 if present.
      // We'll implement robust parsing: if channels >= (5 + 5) => use 4+1+5
      // else if channels == 9 => assume 4+1+4 and map first 4 labels only.
      final channels = output[0].length; // e.g. 9

      // ✅ Your exported TFLite output is [1, 9, 8400] with 5 classes:
      // 9 = 4 (x,y,w,h) + 5 (class scores). There is NO separate objectness channel.
      // So we must decode as:
      //   clsStart = 4
      //   conf = max(classScores)
      // We still keep `objTh` parameter for compatibility; `obj` will be 1.0.

      final int clsStart = 4;
      final int clsCount = (channels - clsStart).clamp(0, labels.length);

      double bestScore = -1;
      int bestClass = -1;
      double bestObj = 1.0;
      double bestCls = 0.0;

      double maxObjRaw = 1.0; // no obj channel
      double maxClsRaw = 0.0;

      double sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

      // Iterate anchors (8400)
      for (int i = 0; i < 8400; i++) {
        // find best class for this anchor
        double localBest = -1;
        int localCls = -1;

        for (int c = 0; c < clsCount; c++) {
          double v = output[0][clsStart + c][i];
          // If model outputs logits (not in 0..1), squash to probability.
          if (v < 0 || v > 1) v = sigmoid(v);
          if (v > maxClsRaw) maxClsRaw = v;
          if (v > localBest) {
            localBest = v;
            localCls = c;
          }
        }

        // score = best class prob (no objectness)
        final score = localBest;
        if (score > bestScore) {
          bestScore = score;
          bestClass = localCls;
          bestCls = localBest;
        }
      }
// map class index -> label
      String label = 'unknown';
      if (bestClass >= 0) {
        if (clsCount == labels.length) {
          label = labels[bestClass];
        } else {
          // fallback if only 4 classes in tensor
          final safeLabels = labels.take(clsCount).toList();
          label = safeLabels[bestClass];
        }
      }

      // thresholds
      final belowTh = (bestObj < objTh) || (bestCls < clsTh);
      final confidence = bestScore.isFinite ? bestScore.clamp(0.0, 1.0) : 0.0;

      return EmotionPrediction(
        label: label,
        confidence: confidence,
        belowThreshold: belowTh,
        obj: bestObj,
        cls: bestCls,
        outShape: outShape,
        maxObjRaw: maxObjRaw,
        maxClsRaw: maxClsRaw,
        error: null,
      );
    } catch (e) {
      return EmotionPrediction(
        label: 'error',
        confidence: 0.0,
        belowThreshold: true,
        obj: 0.0,
        cls: 0.0,
        outShape: 'unknown',
        maxObjRaw: 0.0,
        maxClsRaw: 0.0,
        error: e.toString(),
      );
    }
  }

  /// Float32 NHWC: [1,640,640,3]
  List<List<List<List<double>>>> _imageToFloat32NHWC(img.Image image) {
    final h = image.height;
    final w = image.width;

    final out = List.generate(
      1,
      (_) => List.generate(
        h,
        (_) => List.generate(
          w,
          (_) => List.filled(3, 0.0),
        ),
      ),
    );

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        final r = p.r / 255.0;
        final g = p.g / 255.0;
        final b = p.b / 255.0;
        out[0][y][x][0] = r;
        out[0][y][x][1] = g;
        out[0][y][x][2] = b;
      }
    }
    return out;
  }
}