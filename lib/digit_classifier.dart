// import 'dart:typed_data';
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:image/image.dart' as img;

// class DigitClassifier {
//   late Interpreter _interpreter;
//   final int inputSize = 64;
//   final List<String> labels;

//   DigitClassifier(this.labels);

//   /// Load the TFLite model from assets.
//   Future<void> loadModel() async {
//     _interpreter = await Interpreter.fromAsset('assets/digit_model.tflite');
//   }

//   /// Predicts a digit label (e.g. "3.0") from raw PNG/JPEG bytes.
//   Future<String> predict(Uint8List imageBytes) async {
//     img.Image? image = img.decodeImage(imageBytes);
//     if (image == null) throw Exception('Cannot decode image bytes');
//     img.Image resized = img.copyResize(
//       image,
//       width: inputSize,
//       height: inputSize,
//     );

//     // Build list by reading Pixel.r/g/b directly
//     List<double> rgbList = <double>[];
//     for (int y = 0; y < inputSize; y++) {
//       for (int x = 0; x < inputSize; x++) {
//         var pixel = resized.getPixel(x, y);
//         rgbList.add(pixel.r / 255.0);
//         rgbList.add(pixel.g / 255.0);
//         rgbList.add(pixel.b / 255.0);
//       }
//     }

//     var inputTensor = [Float32List.fromList(rgbList)];
//     var outputBuffer = List.filled(
//       labels.length,
//       0.0,
//     ).reshape([1, labels.length]);
//     _interpreter.run(inputTensor, outputBuffer);

//     List<double> scores = List<double>.from(outputBuffer[0]);
//     int best = scores.indexWhere(
//       (s) => s == scores.reduce((a, b) => a > b ? a : b),
//     );
//     return labels[best];
//   }

//   void close() {
//     _interpreter.close();
//   }
// }
