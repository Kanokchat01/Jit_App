import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// ✅ Realtime face detection for CameraImage stream (camera plugin = YUV420_888)
/// Fix: Convert YUV420 (3 planes) -> NV21 (single plane) for MLKit InputImageMetadata API.
class FaceDetectorService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
      enableTracking: false,
      minFaceSize: 0.15,
    ),
  );

  Future<void> dispose() async => _detector.close();

  Future<Face?> detectLargestFace(
    CameraImage image, {
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    try {
      final input = _toInputImageNV21(
        image,
        camera: camera,
        deviceOrientation: deviceOrientation,
      );

      final faces = await _detector.processImage(input);
      if (faces.isEmpty) return null;

      faces.sort((a, b) {
        final aa = a.boundingBox.width * a.boundingBox.height;
        final bb = b.boundingBox.width * b.boundingBox.height;
        return bb.compareTo(aa);
      });
      return faces.first;
    } catch (_) {
      return null;
    }
  }

  InputImage _toInputImageNV21(
    CameraImage image, {
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final Uint8List nv21 = _yuv420ToNv21(image);

    final Size size = Size(image.width.toDouble(), image.height.toDouble());

    final int deviceDeg = _deviceOrientationToDegrees(deviceOrientation);
    final int sensorDeg = camera.sensorOrientation;
    final bool isFront = camera.lensDirection == CameraLensDirection.front;

    // rotation compensation for MLKit
    final int rot = isFront
        ? (sensorDeg + deviceDeg) % 360
        : (sensorDeg - deviceDeg + 360) % 360;

    final InputImageRotation rotation =
        InputImageRotationValue.fromRawValue(rot) ??
            InputImageRotation.rotation0deg;

    // For NV21, bytesPerRow = image.width
    final InputImageMetadata metadata = InputImageMetadata(
      size: size,
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.width,
    );

    return InputImage.fromBytes(bytes: nv21, metadata: metadata);
  }

  /// YUV420_888 (planes: Y, U, V) -> NV21 (Y + interleaved VU)
  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final Plane planeY = image.planes[0];
    final Plane planeU = image.planes[1];
    final Plane planeV = image.planes[2];

    final Uint8List yBytes = planeY.bytes;
    final Uint8List uBytes = planeU.bytes;
    final Uint8List vBytes = planeV.bytes;

    final int yRowStride = planeY.bytesPerRow;
    final int yPixelStride = planeY.bytesPerPixel ?? 1;

    final int uRowStride = planeU.bytesPerRow;
    final int uPixelStride = planeU.bytesPerPixel ?? 1;

    final int vRowStride = planeV.bytesPerRow;
    final int vPixelStride = planeV.bytesPerPixel ?? 1;

    // NV21: Y (w*h) + VU (w*h/2)
    final Uint8List out = Uint8List(width * height + (width * height) ~/ 2);
    int outIndex = 0;

    // Copy Y with stride
    for (int row = 0; row < height; row++) {
      final int yRowStart = row * yRowStride;
      for (int col = 0; col < width; col++) {
        out[outIndex++] = yBytes[yRowStart + col * yPixelStride];
      }
    }

    // Interleave VU (chroma is half resolution)
    final int chromaHeight = height ~/ 2;
    final int chromaWidth = width ~/ 2;

    for (int row = 0; row < chromaHeight; row++) {
      final int uRowStart = row * uRowStride;
      final int vRowStart = row * vRowStride;
      for (int col = 0; col < chromaWidth; col++) {
        final int uIndex = uRowStart + col * uPixelStride;
        final int vIndex = vRowStart + col * vPixelStride;

        out[outIndex++] = vBytes[vIndex]; // V
        out[outIndex++] = uBytes[uIndex]; // U
      }
    }

    return out;
  }

  int _deviceOrientationToDegrees(DeviceOrientation o) {
    switch (o) {
      case DeviceOrientation.portraitUp:
        return 0;
      case DeviceOrientation.landscapeLeft:
        return 90;
      case DeviceOrientation.portraitDown:
        return 180;
      case DeviceOrientation.landscapeRight:
        return 270;
    }
  }
}