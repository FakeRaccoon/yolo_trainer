// import 'dart:developer';
// import 'dart:io';
// import 'package:flutter/services.dart';
// import 'package:image/image.dart' as img;
// import 'package:tflite_flutter/tflite_flutter.dart';

// class ObjectDetection {
//   static const String _modelPath = 'assets/new_model.tflite';
//   static const String _labelPath = 'assets/labels.txt';

//   Interpreter? _interpreter;
//   List<String>? _labels;

//   ObjectDetection() {
//     _loadModel();
//     _loadLabels();
//     log('Done loading model & labels.');
//   }

//   Future<void> _loadModel() async {
//     log('Loading interpreter options...');
//     final opts = InterpreterOptions();
//     if (Platform.isAndroid) opts.addDelegate(XNNPackDelegate());
//     if (Platform.isIOS) opts.addDelegate(GpuDelegate());
//     log('Creating interpreter...');
//     _interpreter = await Interpreter.fromAsset(_modelPath, options: opts);
//   }

//   Future<void> _loadLabels() async {
//     log('Loading labels...');
//     final raw = await rootBundle.loadString(_labelPath);
//     _labels = raw.split('\n');
//   }

//   /// Main entry: feed in oriented JPEG/PNG bytes, get back annotated JPEG bytes.
//   Uint8List analyseImage(Uint8List orientedImageData) {
//     log('🚀 analyseImage start');

//     // 1️⃣ Get model’s input shape & type
//     final inTensor = _interpreter!.getInputTensor(0);
//     final shape = inTensor.shape; // [1, H, W, 3]
//     final targetH = shape[1];
//     final targetW = shape[2];
//     final dtype = inTensor.type; // TfLiteType.float32
//     log('Model input: type=$dtype, shape=$shape');

//     // 2️⃣ Decode into image.Image
//     final decoded = img.decodeImage(orientedImageData);
//     if (decoded == null) throw Exception('Failed to decode image');

//     // 3️⃣ Resize to exactly model’s dimensions
//     final resized = img.copyResize(decoded, width: targetW, height: targetH);

//     // 4️⃣ Build [1, H, W, 3] float32 input, normalized [0..1]
//     final input = [
//       List.generate(targetH, (y) {
//         return List.generate(targetW, (x) {
//           final p = resized.getPixel(x, y) as img.PixelUint8;
//           return <double>[p.r / 255.0, p.g / 255.0, p.b / 255.0];
//         });
//       }),
//     ];

//     // 5️⃣ Run inference and get raw detections
//     final detections = _runInference(input);

//     // 6️⃣ Draw each detection onto the resized image
//     for (var det in detections) {
//       final box = det['box'] as List<double>; // [x_center, y_center, w, h]
//       final conf = det['conf'] as double;
//       final cls = det['class'] as int;
//       if (conf < 0.5) continue;

//       // Convert to pixel corners
//       final cx = box[0] * targetW;
//       final cy = box[1] * targetH;
//       final w = box[2] * targetW;
//       final h = box[3] * targetH;
//       final x1 = (cx - w / 2).toInt();
//       final y1 = (cy - h / 2).toInt();
//       final x2 = (cx + w / 2).toInt();
//       final y2 = (cy + h / 2).toInt();

//       img.drawRect(
//         resized,
//         x1: x1,
//         y1: y1,
//         x2: x2,
//         y2: y2,
//         color: img.ColorRgb8(0, 255, 0),
//         thickness: 2,
//       );
//       img.drawString(
//         resized,
//         '${_labels![cls]} ${(conf * 100).toStringAsFixed(1)}%',
//         font: img.arial14,
//         x: x1 + 4,
//         y: y1 + 4,
//         color: img.ColorRgb8(0, 255, 0),
//       );
//     }

//     log('✅ analyseImage done');
//     return img.encodeJpg(resized);
//   }

//   /// Runs inference on a single [1,H,W,3] float32 tensor.
//   /// Parses the YOLOv8 output of shape [1, N, 6].
//   List<Map<String, dynamic>> _runInference(
//     List<List<List<List<double>>>> input,
//   ) {
//     log('Running YOLOv8 inference...');

//     // 1️⃣ Inspect output tensor
//     final outTensor = _interpreter!.getOutputTensor(0);
//     final oShape = outTensor.shape; // e.g. [1, 25200, 6]
//     final numPred = oShape[1];
//     final numDims = oShape[2]; // should be 6
//     log('Output tensor: shape=$oShape, type=${outTensor.type}');

//     // 2️⃣ Allocate buffer [1][numPred][6]
//     final outputBuffer = List.generate(
//       1,
//       (_) => List.generate(numPred, (_) => List.filled(numDims, 0.0)),
//     );

//     // 3️⃣ Run model
//     _interpreter!.run(input, outputBuffer);

//     // 4️⃣ Parse results
//     final preds = outputBuffer[0];
//     final results = <Map<String, dynamic>>[];
//     for (var entry in preds) {
//       final conf = entry[4];
//       if (conf < 0.01) continue; // filter out very low confidence
//       results.add({
//         'box': entry.sublist(0, 4),
//         'conf': conf,
//         'class': entry[5].toInt(),
//       });
//     }
//     return results;
//   }
// }
