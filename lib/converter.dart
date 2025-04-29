import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Utility methods for converting and cropping [CameraImage] data
class FlutterImageUtils {
  static Uint8List imageToUint8List(img.Image image) {
    return Uint8List.fromList(
      img.encodeJpg(image),
    ); // Or encodePng if you prefer
  }

  /// Converts a YUV420 [CameraImage] to an [img.Image] in RGB format.
  /// Converts a YUV420 [CameraImage] to an [img.Image] in RGB format.
  static img.Image convertYUV420ToImage(
    CameraImage image, {
    required CameraDescription cameraDescription,
  }) {
    final int width = image.width;
    final int height = image.height;
    final img.Image imgImage = img.Image(width: width, height: height);

    final planeY = image.planes[0];
    final planeU = image.planes[1];
    final planeV = image.planes[2];

    final int rowStrideY = planeY.bytesPerRow;
    final int rowStrideU = planeU.bytesPerRow;
    final int rowStrideV = planeV.bytesPerRow;
    final int pixelStrideU = planeU.bytesPerPixel!;
    final int pixelStrideV = planeV.bytesPerPixel!;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * rowStrideY + x;
        final int yVal = planeY.bytes[yIndex];

        final int uvX = x >> 1;
        final int uvY = y >> 1;

        final int uIndex = uvY * rowStrideU + uvX * pixelStrideU;
        final int vIndex = uvY * rowStrideV + uvX * pixelStrideV;

        final int uVal = planeU.bytes[uIndex];
        final int vVal = planeV.bytes[vIndex];

        final double yD = yVal.toDouble();
        final double uD = uVal - 128.0;
        final double vD = vVal - 128.0;

        int r = (yD + 1.402 * vD).round().clamp(0, 255);
        int g = (yD - 0.344136 * uD - 0.714136 * vD).round().clamp(0, 255);
        int b = (yD + 1.772 * uD).round().clamp(0, 255);

        imgImage.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    // Now fix orientation
    int rotationAngle = 0;

    switch (cameraDescription.sensorOrientation) {
      case 0:
        rotationAngle = 0;
        break;
      case 90:
        rotationAngle = 90;
        break;
      case 180:
        rotationAngle = 180;
        break;
      case 270:
        rotationAngle = -90;
        break;
      default:
        rotationAngle = 0;
    }

    img.Image rotated = imgImage;

    if (rotationAngle != 0) {
      rotated = img.copyRotate(imgImage, angle: rotationAngle);
    }

    // Special handling: if using front camera, mirror horizontally
    if (cameraDescription.lensDirection == CameraLensDirection.front) {
      rotated = img.flipHorizontal(rotated);
    }

    return rotated;
  }

  /// Crops a region from [baseImage], using box coordinates as [List<double> box = [x1, y1, x2, y2, score]]
  /// [padding]: pixels to expand around the box
  /// [targetSize]: if provided, resizes cropped area to square [targetSize]x[targetSize]
  /// [asJpeg]: if true, encodes result as JPEG; otherwise PNG
  /// [quality]: JPEG quality (0-100)
  static Uint8List cropImageFromBox(
    img.Image baseImage,
    List<dynamic> box, {
    int padding = 10,
    int? targetSize,
    bool asJpeg = false,
    int quality = 90,
  }) {
    // Extract box coordinates from the list (x1, y1, x2, y2, score)
    final double x1 = box[0];
    final double y1 = box[1];
    final double x2 = box[2];
    final double y2 = box[3];

    // Convert to rotated coordinates (adjust for possible image rotation)
    final int rotationAngle =
        0; // You may need to dynamically get this based on camera orientation

    double x = x1;
    double y = y1;
    double width = x2 - x1;
    double height = y2 - y1;

    // Handle rotation adjustments if needed
    if (rotationAngle == 90 || rotationAngle == 270) {
      // Swap width and height for rotated images
      final temp = width;
      width = height;
      height = temp;

      // Adjust the x and y coordinates for the new orientation
      x = baseImage.height - y2;
      y = x1;
    }

    return cropImage(
      baseImage,
      x,
      y,
      width,
      height,
      padding: padding,
      targetSize: targetSize,
      asJpeg: asJpeg,
      quality: quality,
    );
  }

  /// Crops a region from [baseImage], with optional padding, resizing, and format
  /// [x], [y], [width], [height]: region in image coordinates (double ok)
  /// [padding]: pixels to expand around the box
  /// [targetSize]: if provided, resizes cropped area to square [targetSize]x[targetSize]
  /// [asJpeg]: if true, encodes result as JPEG; otherwise PNG
  /// [quality]: JPEG quality (0-100)
  static Uint8List cropImage(
    img.Image baseImage,
    double x,
    double y,
    double width,
    double height, {
    int padding = 10,
    int? targetSize,
    bool asJpeg = false,
    int quality = 90,
  }) {
    final int ix = (x - padding).clamp(0, baseImage.width).toInt();
    final int iy = (y - padding).clamp(0, baseImage.height).toInt();
    final int iw =
        ((x + width + padding) - ix).clamp(0, baseImage.width - ix).toInt();
    final int ih =
        ((y + height + padding) - iy).clamp(0, baseImage.height - iy).toInt();

    img.Image cropped = img.copyCrop(
      baseImage,
      x: ix,
      y: iy,
      width: iw,
      height: ih,
    );

    if (targetSize != null && targetSize > 0) {
      cropped = img.copyResizeCropSquare(cropped, size: targetSize);
    }

    if (asJpeg) {
      return Uint8List.fromList(img.encodeJpg(cropped, quality: quality));
    }
    return Uint8List.fromList(img.encodePng(cropped));
  }
}
