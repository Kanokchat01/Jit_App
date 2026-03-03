import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'dart:ui' show Rect;

/// แปลง CameraImage (YUV420) -> Float32List tensor แบบตรง ๆ
/// - ตัดการสร้าง img.Image และการ resize ผ่าน image package
/// - เร็วกว่าเยอะ (ช่วยลด lag ตอนกล้องทำงาน)
///
/// รองรับ:
/// - mirror (กล้องหน้า)
/// - cropRect (ตัดกรอบสี่เหลี่ยมก่อนย่อ/ขยาย ถ้า null จะใช้เต็มภาพ)
/// - normalize: [0..1] หรือ [-1..1]
/// - swapUV บางเครื่อง U/V สลับกัน (หน้าคนเขียว/ม่วง)
///
/// ใช้ integer YUV->RGB (เร็ว) หรือแบบ bytes ตรงๆ สำหรับ BGRA
Float32List cameraImageToTensor(
  CameraImage image, {
  required int targetW,
  required int targetH,
  required int inputC, // 1 หรือ 3
  required bool normalizeMinusOneToOne,
  bool mirror = false,
  Rect? cropRect,
  bool swapUV = false,
  Float32List? reuseBuffer,
}) {
  final int srcW = image.width;
  final int srcH = image.height;

  // เลือก crop area ใน source
  int cropX = 0, cropY = 0, cropW = srcW, cropH = srcH;
  if (cropRect != null) {
    cropX = cropRect.left.floor().clamp(0, srcW - 1);
    cropY = cropRect.top.floor().clamp(0, srcH - 1);
    cropW = cropRect.width.floor().clamp(1, srcW - cropX);
    cropH = cropRect.height.floor().clamp(1, srcH - cropY);
  }

  final int outLen = targetW * targetH * inputC;
  final Float32List out = (reuseBuffer != null && reuseBuffer.length == outLen)
      ? reuseBuffer
      : Float32List(outLen);

  // scale mapping: dst -> src
  final double scaleX = cropW / targetW;
  final double scaleY = cropH / targetH;

  int idx = 0;

  if (image.format.group == ImageFormatGroup.bgra8888) {
    final Uint8List bytes = image.planes[0].bytes;
    final int bytesPerRow = image.planes[0].bytesPerRow;
    final int bytesPerPixel = image.planes[0].bytesPerPixel ?? 4;

    for (int dy = 0; dy < targetH; dy++) {
      final int sy = (cropY + (dy * scaleY)).floor().clamp(0, srcH - 1);
      final int rowOffset = sy * bytesPerRow;

      for (int dx = 0; dx < targetW; dx++) {
        final int mx = mirror ? (targetW - 1 - dx) : dx;
        final int sx = (cropX + (mx * scaleX)).floor().clamp(0, srcW - 1);
        final int offset = rowOffset + sx * bytesPerPixel;

        int b = bytes[offset];
        int g = bytes[offset + 1];
        int r = bytes[offset + 2];

        double rf = r / 255.0;
        double gf = g / 255.0;
        double bf = b / 255.0;

        if (normalizeMinusOneToOne) {
          rf = rf * 2.0 - 1.0;
          gf = gf * 2.0 - 1.0;
          bf = bf * 2.0 - 1.0;
        }

        if (inputC == 3) {
          out[idx++] = rf;
          out[idx++] = gf;
          out[idx++] = bf;
        } else if (inputC == 1) {
          out[idx++] = (0.299 * rf + 0.587 * gf + 0.114 * bf);
        }
      }
    }
  } else {
    // YUV420
    final planeY = image.planes[0];
    final planeU = image.planes[1];
    final planeV = image.planes[2];

    final Uint8List bytesY = planeY.bytes;
    final Uint8List bytesU = planeU.bytes;
    final Uint8List bytesV = planeV.bytes;

    final int yRowStride = planeY.bytesPerRow;
    final int uvRowStride = planeU.bytesPerRow;
    final int uvPixelStride = planeU.bytesPerPixel ?? 1;

    for (int dy = 0; dy < targetH; dy++) {
      // map y
      final int sy = (cropY + (dy * scaleY)).floor().clamp(0, srcH - 1);



    final int yRow = sy * yRowStride;
    final int uvRow = (sy >> 1) * uvRowStride;

    for (int dx = 0; dx < targetW; dx++) {
      // map x (mirror ถ้าเป็นกล้องหน้า)
      final int mx = mirror ? (targetW - 1 - dx) : dx;
      final int sx = (cropX + (mx * scaleX)).floor().clamp(0, srcW - 1);

      final int yIndex = yRow + sx;
      final int uvIndex = uvRow + (sx >> 1) * uvPixelStride;

      final int Y = bytesY[yIndex] & 0xFF;

      int U = bytesU[uvIndex] & 0xFF;
      int V = bytesV[uvIndex] & 0xFF;

      if (swapUV) {
        final t = U;
        U = V;
        V = t;
      }

      // Integer YUV->RGB (เร็ว)
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

      double r = R / 255.0;
      double g = G / 255.0;
      double b = B / 255.0;

      if (normalizeMinusOneToOne) {
        r = r * 2.0 - 1.0;
        g = g * 2.0 - 1.0;
        b = b * 2.0 - 1.0;
      }

      if (inputC == 3) {
        out[idx++] = r;
        out[idx++] = g;
        out[idx++] = b;
      } else if (inputC == 1) {
        out[idx++] = (0.299 * r + 0.587 * g + 0.114 * b);
        } else {
          throw StateError('Unsupported inputC=$inputC (expected 1 or 3)');
        }
      }
    }
  }

  return out;
}