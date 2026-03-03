import 'dart:math' as math;
import 'dart:typed_data';

import 'dart:isolate';
import 'package:flutter/services.dart';
import 'emotion_isolate_worker.dart';

class EmotionPrediction {
  final String label;
  final double confidence;

  /// ✅ ทุก class score จาก best anchor (ให้ aggregator ใช้)
  final Map<String, double> allScores;

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
    required this.allScores,
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
  Isolate? _isolate;
  SendPort? _sendPort;
  bool _isLoading = false;

  // ตาม metadata.yaml ของหนู
  static const List<String> labels = ['angry', 'fear', 'happy', 'neutral', 'sad'];

  final int everyNFrames;
  int _frameCount = 0;

  EmotionInferenceService({this.everyNFrames = 1});

  bool get isLoaded => _sendPort != null;

  Future<void> load() async {
    if (isLoaded || _isLoading) return;
    _isLoading = true;

    try {
      final modelData = await rootBundle.load('assets/models/emotion_model.tflite');
      final modelBytes = modelData.buffer.asUint8List();

      final receivePort = ReceivePort();
      _isolate = await Isolate.spawn(emotionIsolateEntry, receivePort.sendPort);

      // get sendPort
      _sendPort = await receivePort.first as SendPort;

      // send load message
      final loadPort = ReceivePort();
      _sendPort!.send(LoadMsg(modelBytes, loadPort.sendPort));

      final success = await loadPort.first as bool;
      if (!success) {
        throw Exception('Failed to load model in isolate');
      }
    } finally {
      _isLoading = false;
    }
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
  }

  Future<EmotionPrediction?> predictFromCameraImageMap(
    Map<String, dynamic> imageMap, {
    required Map<String, double>? faceBox,
    required bool useFaceDetector,
    required double objTh,
    required double clsTh,
    bool debug = false,
  }) async {
    try {
      if (!isLoaded) return null;

      _frameCount++;
      if (everyNFrames > 1 && (_frameCount % everyNFrames != 0)) {
        return null;
      }

      final replyPort = ReceivePort();
      _sendPort!.send(PredictMsg(
        imageMap: imageMap,
        faceBox: faceBox,
        useFaceDetector: useFaceDetector,
        replyTo: replyPort.sendPort,
        objTh: objTh,
        clsTh: clsTh,
        debug: debug,
      ));

      final result = await replyPort.first;
      
      if (result == null) return null;
      if (result is Map) {
        if (result.containsKey('error')) {
          return EmotionPrediction(
            label: 'error',
            confidence: 0.0,
            allScores: const {},
            belowThreshold: true,
            obj: 0.0,
            cls: 0.0,
            outShape: result['outShape']?.toString() ?? 'unknown',
            maxObjRaw: 0.0,
            maxClsRaw: 0.0,
            error: result['error'].toString(),
          );
        }

        // ✅ parse allScores จาก isolate
        final rawScores = result['allScores'];
        final Map<String, double> allScores = {};
        if (rawScores is Map) {
          for (final e in rawScores.entries) {
            allScores[e.key.toString()] = (e.value as num).toDouble();
          }
        }

        return EmotionPrediction(
          label: result['label'] as String,
          confidence: (result['confidence'] as num).toDouble(),
          allScores: allScores,
          belowThreshold: result['belowThreshold'] as bool,
          obj: (result['obj'] as num).toDouble(),
          cls: (result['cls'] as num).toDouble(),
          outShape: result['outShape']?.toString() ?? 'unknown',
          maxObjRaw: result['maxObjRaw'] != null ? (result['maxObjRaw'] as num).toDouble() : 0.0,
          maxClsRaw: result['maxClsRaw'] != null ? (result['maxClsRaw'] as num).toDouble() : 0.0,
          error: null,
        );
      }

      return null;
    } catch (e) {
      return EmotionPrediction(
        label: 'error',
        confidence: 0.0,
        allScores: const {},
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


}