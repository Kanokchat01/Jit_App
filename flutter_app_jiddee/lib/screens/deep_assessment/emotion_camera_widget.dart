import 'dart:async';
import 'dart:ui' show Rect;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'dart:io';
import 'package:image/image.dart' as img;

import 'emotion_inference_service.dart';
import 'emotion_aggregator.dart';
import 'face_detector_service.dart';

class EmotionCameraWidget extends StatefulWidget {
  final EmotionInferenceService service;
  final EmotionAggregator aggregator;
  final bool showPreview;
  final bool useFaceDetector;

  final void Function(
    String label,
    double conf,
    int samples,
    double avgConf,
    String debug,
  )? onUpdate;

  const EmotionCameraWidget({
    super.key,
    required this.service,
    required this.aggregator,
    this.showPreview = false,
    this.useFaceDetector = true,
    this.onUpdate,
  });

  @override
  State<EmotionCameraWidget> createState() => _EmotionCameraWidgetState();
}

class _EmotionCameraWidgetState extends State<EmotionCameraWidget> {
  CameraController? _controller;
  CameraDescription? _camera;
  FaceDetectorService? _faceService;

  bool _starting = true;
  bool _streamStarted = false;
  bool _busy = false;

  String _liveLabel = '...';
  double _liveConf = 0.0;
  String _debugText = '';

  int _lastInferMs = 0;
  int _lastUiMs = 0;
  int _lastFaceMs = 0;

  // ✅ ลดโหลดเพื่อไม่ให้เฟรมหลุด (ช่วยให้ face detect เสถียร)
  final int _inferEveryMs = 350;
  final int _uiEveryMs = 200;
  final int _faceEveryMs = 600;

  Rect? _lastFaceBox;
  int _lastFaceBoxMs = 0;
  final int _faceBoxMaxAgeMs = 2500;

  // For YOLO only
  final bool _swapUV = true;
  final int _downSampleRgb = 1;

  final double _objTh = 0.01;
  final double _clsTh = 0.01;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await widget.service.load();
      if (widget.useFaceDetector) _faceService = FaceDetectorService();
      await _initCamera();
      if (!mounted) return;
      setState(() => _starting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      _setLive('init-fail', 0.0, debug: 'init error: $e');
    }
  }

  Future<void> _initCamera() async {
    final cams = await availableCameras();
    final front = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );
    _camera = front;

    _controller = CameraController(
      front,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    await _startStream();
  }

  @override
  void dispose() {
    _stopStream();
    _controller?.dispose();
    _faceService?.dispose();
    super.dispose();
  }

  Future<void> _startStream() async {
    if (_controller == null || _camera == null) return;
    if (_streamStarted) return;
    _streamStarted = true;

    await _controller!.startImageStream((CameraImage camImg) async {
      if (!mounted) return;
      if (_busy) return;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastInferMs < _inferEveryMs) return;
      _lastInferMs = nowMs;

      _busy = true;
      try {
        // 1) Face detection (NV21) throttled
        String faceStatus = 'OFF';
        if (widget.useFaceDetector && _faceService != null) {
          faceStatus = await _maybeUpdateFaceBox(camImg, nowMs);
        }

        // 2) Pack raw camera image data to delegate processing to backend Isolate
        final imageMap = {
          'width': camImg.width,
          'height': camImg.height,
          'formatGroup': camImg.format.group.name,
          'planes': camImg.planes.map((p) => {
                'bytes': p.bytes,
                'bytesPerRow': p.bytesPerRow,
                'bytesPerPixel': p.bytesPerPixel,
              }).toList(),
          'sensorOrientation': _camera!.sensorOrientation,
          'lensDirection': _camera!.lensDirection.name,
          'deviceOrientation': _controller?.value.deviceOrientation.name ?? 'portraitUp',
        };

        Map<String, double>? faceBoxMap;
        if (widget.useFaceDetector && _lastFaceBox != null && (nowMs - _lastFaceBoxMs) <= _faceBoxMaxAgeMs) {
          faceBoxMap = {
            'left': _lastFaceBox!.left,
            'top': _lastFaceBox!.top,
            'width': _lastFaceBox!.width,
            'height': _lastFaceBox!.height,
          };
        } else if (widget.useFaceDetector) {
          _maybeSetUi(nowMs, 'no-face', 0.0, debug: 'face:$faceStatus skip(no-face)');
          return;
        }

        // 4) Predict on Isolate
        final pred = await widget.service.predictFromCameraImageMap(
          imageMap,
          faceBox: faceBoxMap,
          useFaceDetector: widget.useFaceDetector,
          objTh: _objTh,
          clsTh: _clsTh,
          debug: true,
        );

        if (pred == null) {
          _maybeSetUi(nowMs, 'no-pred', 0.0,
              debug: 'face:$faceStatus pred=null');
          return;
        }

        // ✅ ส่ง allScores ให้ aggregator (แม่นกว่าส่งแค่ label)
        if (pred.allScores.isNotEmpty) {
          widget.aggregator.addSampleAll(pred.allScores);
        } else {
          widget.aggregator.addSample(pred.label, pred.confidence);
        }
        final cur = widget.aggregator.current;

        final label = cur?.label ?? pred.label;
        final conf = cur?.confidence ?? pred.confidence;

        final dbg =
            'face:$faceStatus belowTh:${pred.belowThreshold} obj:${pred.obj.toStringAsFixed(3)} cls:${pred.cls.toStringAsFixed(3)} '
            'shape:${pred.outShape} maxObjRaw:${pred.maxObjRaw} maxClsRaw:${pred.maxClsRaw} err:${pred.error}';

        _maybeSetUi(nowMs, label, conf, debug: dbg);
      } catch (e) {
        _maybeSetUi(DateTime.now().millisecondsSinceEpoch, 'error', 0.0,
            debug: 'stream error: $e');
      } finally {
        _busy = false;
      }
    });
  }

  Future<String> _maybeUpdateFaceBox(CameraImage camImg, int nowMs) async {
    String status = 'N';
    if (_lastFaceBox != null && (nowMs - _lastFaceBoxMs) <= _faceBoxMaxAgeMs) {
      status = 'Y(cached)';
    }

    if (nowMs - _lastFaceMs < _faceEveryMs) return status;
    _lastFaceMs = nowMs;

    final DeviceOrientation devOri =
        _controller?.value.deviceOrientation ?? DeviceOrientation.portraitUp;

    final face = await _faceService!.detectLargestFace(
      camImg,
      camera: _camera!,
      deviceOrientation: devOri,
    );

    if (face != null) {
      _lastFaceBox = face.boundingBox;
      _lastFaceBoxMs = nowMs;
      return 'Y';
    }
    return status.startsWith('Y') ? status : 'N';
  }



  void _maybeSetUi(int nowMs, String label, double conf, {required String debug}) {
    if (nowMs - _lastUiMs < _uiEveryMs) return;
    _lastUiMs = nowMs;
    _setLive(label, conf, debug: debug);
  }

  void _setLive(String label, double conf, {required String debug}) {
    _liveLabel = label;
    _liveConf = conf;
    _debugText = debug;

    final samples = widget.aggregator.samples;
    final avg = widget.aggregator.avgConfidence;

    // ignore: avoid_print
    print('EMO live=$label conf=$conf samples=$samples avg=$avg debug=$debug');

    widget.onUpdate?.call(_liveLabel, _liveConf, samples, avg, _debugText);

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _stopStream() async {
    try {
      if (_controller != null && _controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
    } catch (_) {} finally {
      _streamStarted = false;
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_starting || _controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    if (!widget.showPreview) return const SizedBox.shrink();

    return SizedBox(
      height: 220,
      child: CameraPreview(_controller!),
    );
  }
}