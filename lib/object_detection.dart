// import 'dart:async';
// import 'dart:developer';
// import 'dart:typed_data';
// import 'dart:io';
// import 'dart:math' as math;
// import 'dart:ui'; // for Rect, Offset
// import 'package:flutter/services.dart';
// import 'package:image/image.dart' as img;
// import 'package:tflite_flutter/tflite_flutter.dart';

// /// A single detected object
// class Detection {
//   final Rect box; // in pixel coordinates
//   final double score; // confidence
//   final String label; // class name

//   Detection(this.box, this.score, this.label);
// }

// /// The result of a single inference:
// /// - annotatedImage: the JPEG bytes with boxes drawn
// /// - detections: list of raw boxes, scores & labels
// class DetectionResult {
//   final Uint8List annotatedImage;
//   final List<Detection> detections;

//   DetectionResult(this.annotatedImage, this.detections);
// }

// /// ObjectDetection can be instantiated directly. It will load the model
// /// and labels asynchronously. Calling [analyseImage] will await initialization.
// class ObjectDetection {
//   static const _modelPath = 'assets/new_model.tflite';
//   static const _labelPath = 'assets/labels.txt';

//   Interpreter? _interpreter;
//   List<String>? _labels;
//   late final Future<void> _initFuture;

//   /// Public constructor starts loading model & labels in background.
//   ObjectDetection() {
//     _initFuture = _init();
//   }

//   /// Internal init: load TFLite and labels.
//   Future<void> _init() async {
//     final opts = InterpreterOptions();
//     if (Platform.isAndroid) opts.addDelegate(XNNPackDelegate());
//     if (Platform.isIOS) opts.addDelegate(GpuDelegate());
//     _interpreter = await Interpreter.fromAsset(_modelPath, options: opts);
//     _interpreter!.allocateTensors();
//     final rawLabels = await rootBundle.loadString(_labelPath);
//     _labels =
//         rawLabels.split(RegExp(r"\r?\n")).where((s) => s.isNotEmpty).toList();
//     log('Model & labels loaded.');
//   }

//   /// Letterbox: resize with padding to maintain aspect ratio.
//   img.Image _letterbox(img.Image src, int targetW, int targetH) {
//     final scale = math.min(targetW / src.width, targetH / src.height);
//     final newW = (src.width * scale).round();
//     final newH = (src.height * scale).round();
//     final resized = img.copyResize(src, width: newW, height: newH);
//     final out = img.Image(width: targetW, height: targetH);
//     // final gray = img.rgbaToUint32(114, 114, 114, 255);
//     img.fill(out, color: img.ColorFloat32.rgb(114, 114, 255));
//     final dx = ((targetW - newW) / 2).round();
//     final dy = ((targetH - newH) / 2).round();
//     img.compositeImage(
//       out,
//       resized,
//       dstX: dx,
//       dstY: dy,
//       blend: img.BlendMode.alpha,
//     );
//     return out;
//   }

//   /// Runs inference on JPEG bytes and returns annotated JPEG + detections.
//   Future<DetectionResult> analyseImage(Uint8List inputBytes) async {
//     // ensure model & labels are loaded
//     await _initFuture;
//     final interpreter = _interpreter!;
//     final labels = _labels!;

//     final src = img.decodeImage(inputBytes)!;
//     final originalW = src.width;
//     final originalH = src.height;

//     final inputTensor = interpreter.getInputTensors().first;
//     final h = inputTensor.shape[1], w = inputTensor.shape[2];
//     final prepped = _letterbox(src, w, h);
//     final input = List.generate(
//       1,
//       (_) => List.generate(
//         h,
//         (y) => List.generate(w, (x) {
//           final p = prepped.getPixel(x, y);
//           return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
//         }),
//       ),
//     );

//     final outputTensor = interpreter.getOutputTensors().first;
//     final numPred = outputTensor.shape[1], numDims = outputTensor.shape[2];
//     final outputBuffer = List.generate(
//       1,
//       (_) => List.generate(numPred, (_) => List.filled(numDims, 0.0)),
//     );
//     interpreter.run(input, outputBuffer);

//     final raw =
//         outputBuffer[0]
//             .where((e) => e[4] > 0.25)
//             .map(
//               (e) => {
//                 'box': e.sublist(0, 4),
//                 'conf': e[4],
//                 'cls': e[5].toInt(),
//               },
//             )
//             .toList();
//     final kept = _nonMaxSuppression(raw, 0.45);

//     final dets =
//         kept.map((m) {
//           final b = m['box'] as List<double>;
//           final conf = m['conf'] as double;
//           final cls = m['cls'] as int;
//           final cx = b[0] * originalW;
//           final cy = b[1] * originalH;
//           final ww = b[2] * originalW;
//           final hh = b[3] * originalH;
//           return Detection(
//             Rect.fromCenter(center: Offset(cx, cy), width: ww, height: hh),
//             conf,
//             labels[cls],
//           );
//         }).toList();

//     final annotated = img.copyResize(src, width: originalW, height: originalH);
//     // final green = img.rgbaToUint32(0, 255, 0, 255);
//     for (var d in dets) {
//       final r = d.box;
//       img.drawRect(
//         annotated,
//         x1: r.left.toInt(),
//         y1: r.top.toInt(),
//         x2: r.right.toInt(),
//         y2: r.bottom.toInt(),
//         color: img.ColorFloat32.rgb(0, 255, 0),
//       );
//     }

//     final jpg = img.encodeJpg(annotated);
//     return DetectionResult(Uint8List.fromList(jpg), dets);
//   }

//   List<Map<String, dynamic>> _nonMaxSuppression(
//     List<Map<String, dynamic>> preds,
//     double iouTh,
//   ) {
//     preds.sort((a, b) => (b['conf'] as double).compareTo(a['conf'] as double));
//     final keep = <Map<String, dynamic>>[];
//     for (var p in preds) {
//       bool overlap = false;
//       final b1 = p['box'] as List<double>;
//       final r1 = Rect.fromCenter(
//         center: Offset(b1[0], b1[1]),
//         width: b1[2],
//         height: b1[3],
//       );
//       for (var q in keep) {
//         final b2 = q['box'] as List<double>;
//         final r2 = Rect.fromCenter(
//           center: Offset(b2[0], b2[1]),
//           width: b2[2],
//           height: b2[3],
//         );
//         if (_iou(r1, r2) > iouTh) {
//           overlap = true;
//           break;
//         }
//       }
//       if (!overlap) keep.add(p);
//     }
//     return keep;
//   }

//   double _iou(Rect a, Rect b) {
//     final inter = a.intersect(b);
//     if (inter.isEmpty) return 0;
//     final interArea = inter.width * inter.height;
//     return interArea / (a.width * a.height + b.width * b.height - interArea);
//   }
// }
