import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class LoadMsg {
  final Uint8List modelBytes;
  final SendPort replyTo;
  LoadMsg(this.modelBytes, this.replyTo);
}

class PredictMsg {
  final Float32List input;
  final SendPort replyTo;
  final double objTh;
  final double clsTh;

  /// ถ้า true จะส่ง debug กลับไปด้วย
  final bool debug;
  PredictMsg(this.input, this.replyTo, this.objTh, this.clsTh, {this.debug = false});
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
  // ถ้าค่า logits เกิน 1.2 ถือว่าน่าจะยังไม่ sigmoid
  final n = feats[0].length;
  final limit = min(20, n);
  for (int i = 0; i < limit; i++) {
    if (feats[4][i] > 1.2) return true;
    if (feats.length > 5 && feats[5][i] > 1.2) return true;
  }
  return false;
}

bool _needsSigmoidHWC(List<List<double>> feats) {
  final n = feats.length;
  final limit = min(20, n);
  for (int i = 0; i < limit; i++) {
    if (feats[i].length > 4 && feats[i][4] > 1.2) return true;
    if (feats[i].length > 5 && feats[i][5] > 1.2) return true;
  }
  return false;
}

/// decode แบบ “robust”
/// - รองรับ channels != 10 (เช่น 9/11) โดยใช้ channels-5 เป็นจำนวนคลาส
/// - ถ้าไม่มีอะไรผ่าน threshold จะคืน "best ที่เจอ" แบบ belowThreshold=true เพื่อ debug
Map<String, dynamic>? _decodeBest(dynamic output, List<int> shape, double objTh, double clsTh, {bool debug = false}) {
  final b = shape[1];
  final c = shape[2];

  // รูปแบบยอดนิยม:
  // CHW: [1, channels, 8400]
  // HWC: [1, 8400, channels]
  final isCHW = (c >= 1000 && b <= 64); // heuristic
  final isHWC = (b >= 1000 && c <= 64);

  double bestScore = -1;
  double bestObj = 0;
  double bestCls = 0;
  int bestClass = -1;

  double maxObjSeen = -1e9;
  double maxClsSeen = -1e9;
  bool useSigmoid = true;
  bool belowThreshold = false;

  if (isCHW) {
    final feats = output[0] as List<List<double>>; // [channels][N]
    final channels = feats.length;
    final n = feats[0].length;
    final nc = max(0, channels - 5);

    useSigmoid = _needsSigmoidCHW(feats);

    for (int i = 0; i < n; i++) {
      double obj = feats[4][i];
      maxObjSeen = max(maxObjSeen, obj);
      if (useSigmoid) obj = _sigmoid(obj);

      double bestClsLocal = -1;
      int clsIdx = -1;

      for (int k = 0; k < nc; k++) {
        double p = feats[5 + k][i];
        maxClsSeen = max(maxClsSeen, p);
        if (useSigmoid) p = _sigmoid(p);
        if (p > bestClsLocal) {
          bestClsLocal = p;
          clsIdx = k;
        }
      }

      final score = obj * bestClsLocal;
      if (score > bestScore) {
        bestScore = score;
        bestObj = obj;
        bestCls = bestClsLocal;
        bestClass = clsIdx;
      }
    }

    // threshold gate (แต่ยังคืน best ได้เพื่อ debug)
    if (!(bestObj >= objTh && bestCls >= clsTh)) belowThreshold = true;

  } else if (isHWC) {
    final feats = output[0] as List<List<double>>; // [N][channels]
    final n = feats.length;
    final channels = feats[0].length;
    final nc = max(0, channels - 5);

    useSigmoid = _needsSigmoidHWC(feats);

    for (int i = 0; i < n; i++) {
      if (feats[i].length < 6) continue;

      double obj = feats[i][4];
      maxObjSeen = max(maxObjSeen, obj);
      if (useSigmoid) obj = _sigmoid(obj);

      double bestClsLocal = -1;
      int clsIdx = -1;

      for (int k = 0; k < nc; k++) {
        double p = feats[i][5 + k];
        maxClsSeen = max(maxClsSeen, p);
        if (useSigmoid) p = _sigmoid(p);
        if (p > bestClsLocal) {
          bestClsLocal = p;
          clsIdx = k;
        }
      }

      final score = obj * bestClsLocal;
      if (score > bestScore) {
        bestScore = score;
        bestObj = obj;
        bestCls = bestClsLocal;
        bestClass = clsIdx;
      }
    }

    if (!(bestObj >= objTh && bestCls >= clsTh)) belowThreshold = true;

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

  final resp = <String, dynamic>{
    'classIndex': safeIdx,
    'label': _labels[safeIdx],
    'confidence': bestScore.isFinite ? bestScore : 0.0,
    'obj': bestObj,
    'cls': bestCls,
    'belowThreshold': belowThreshold,
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
        final inputTensor = msg.input.reshape([1, 640, 640, 3]);
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