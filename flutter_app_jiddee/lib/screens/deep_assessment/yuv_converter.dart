import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:image/image.dart' as img;

/// Convert CameraImage (YUV420_888) -> RGB img.Image
///
/// ✅ เพิ่ม:
/// - rotate ให้ตรงกับ MLKit (0/90/180/270)
/// - flipHorizontal สำหรับกล้องหน้า (Front camera mirror)
///
/// พารามิเตอร์ใหม่:
/// - camera: CameraDescription (ต้องมีเพื่อรู้ front/back + sensorOrientation)
/// - deviceOrientation: DeviceOrientation (จาก controller.value.deviceOrientation)
img.Image? convertCameraImageToImage(
  CameraImage image, {
  bool swapUV = false,
  int downSample = 2,
  CameraDescription? camera,
  DeviceOrientation? deviceOrientation,
  bool alignToMlkit = true, // ✅ ถ้าต้องการให้ภาพตรงกับ MLKit
}) {
  try {
    final int srcW = image.width;
    final int srcH = image.height;

    // clamp downSample
    if (downSample < 1) downSample = 1;
    if (downSample != 1 && downSample != 2 && downSample != 4) {
      downSample = 2;
    }

    final int outW = srcW ~/ downSample;
    final int outH = srcH ~/ downSample;

    final out = img.Image(width: outW, height: outH);

    if (image.format.group == ImageFormatGroup.bgra8888) {
      final Uint8List bytes = image.planes[0].bytes;
      final int bytesPerRow = image.planes[0].bytesPerRow;
      final int bytesPerPixel = image.planes[0].bytesPerPixel ?? 4;
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
      final planeY = image.planes[0];
      final planeU = image.planes[1];
      final planeV = image.planes[2];

      final Uint8List bytesY = planeY.bytes;
      final Uint8List bytesU = planeU.bytes;
      final Uint8List bytesV = planeV.bytes;

      final int yRowStride = planeY.bytesPerRow;
      final int uvRowStride = planeU.bytesPerRow;
      final int uvPixelStride = planeU.bytesPerPixel ?? 1;

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

          // Fast integer YUV->RGB (BT.601-ish)
          int C = Y - 16;
          if (C < 0) C = 0;

          final int D = U - 128;
          final int E = V - 128;

          int R = (298 * C + 409 * E + 128) >> 8;
          int G = (298 * C - 100 * D - 208 * E + 128) >> 8;
          int B = (298 * C + 516 * D + 128) >> 8;

          // clamp 0..255
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

    // ✅ ทำให้ภาพ “ตรงกับ MLKit” เพื่อให้ boundingBox/crop ไม่เพี้ยน
    if (alignToMlkit && camera != null) {
      final int rot = _computeRotationCompensation(
        camera: camera,
        deviceOrientation: deviceOrientation ?? DeviceOrientation.portraitUp,
      );

      img.Image fixed = out;

      if (rot == 90) {
        fixed = img.copyRotate(fixed, angle: 90);
      } else if (rot == 180) {
        fixed = img.copyRotate(fixed, angle: 180);
      } else if (rot == 270) {
        fixed = img.copyRotate(fixed, angle: 270);
      }

      // ✅ กล้องหน้ามักเป็น mirror ต้อง flip เพื่อให้พิกัด bbox ตรง
      if (camera.lensDirection == CameraLensDirection.front) {
        fixed = img.flipHorizontal(fixed);
      }

      return fixed;
    }

    return out;
  } catch (_) {
    return null;
  }
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

/// Rotation compensation ให้สอดคล้องกับ MLKit:
/// - front: (sensor + device) % 360
/// - back : (sensor - device + 360) % 360
int _computeRotationCompensation({
  required CameraDescription camera,
  required DeviceOrientation deviceOrientation,
}) {
  final int deviceDeg = _deviceOrientationToDegrees(deviceOrientation);
  final int sensorDeg = camera.sensorOrientation;
  final bool isFront = camera.lensDirection == CameraLensDirection.front;

  return isFront
      ? (sensorDeg + deviceDeg) % 360
      : (sensorDeg - deviceDeg + 360) % 360;
}