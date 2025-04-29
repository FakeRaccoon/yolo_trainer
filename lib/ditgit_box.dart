// import 'dart:async';
// import 'dart:developer';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:flutter_vision/flutter_vision.dart';
// import 'package:image/image.dart' as img;
// import 'package:path_provider/path_provider.dart';

// late List<CameraDescription> cameras;

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   cameras = await availableCameras();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(theme: ThemeData.dark(), home: const CameraHome());
//   }
// }

// class CameraHome extends StatefulWidget {
//   const CameraHome({super.key});

//   @override
//   CameraHomeState createState() => CameraHomeState();
// }

// class CameraHomeState extends State<CameraHome> {
//   late CameraController _cameraController;
//   late FlutterVision _vision;
//   bool _isInitializing = true;
//   bool _isDetecting = false;

//   CameraImage? _cameraImage;
//   List<Map<String, dynamic>> _yoloResults = [];

//   final _yoloResultsStreamController =
//       StreamController<List<Map<String, dynamic>>>.broadcast();
//   Stream<List<Map<String, dynamic>>> get yoloResultsStream =>
//       _yoloResultsStreamController.stream;

//   @override
//   void initState() {
//     super.initState();
//     _cameraController = CameraController(
//       cameras[0],
//       ResolutionPreset.medium,
//       enableAudio: false,
//     );
//     _initializeCamera();
//   }

//   Future<void> _initializeCamera() async {
//     await _cameraController.initialize();
//     _vision = FlutterVision();
//     await _vision.loadYoloModel(
//       labels: 'assets/label_meter.txt',
//       modelPath: 'assets/latest_model.tflite',
//       modelVersion: 'yolov8',
//     );
//     // await _vision.loadYoloModel(
//     //   labels: 'assets/labels.txt',
//     //   modelPath: 'assets/new_model.tflite',
//     //   modelVersion: 'yolov8',
//     //   quantization: true,
//     // );
//     _cameraController.startImageStream(_processCameraImage);
//     setState(() => _isInitializing = false);
//   }

//   List<List<Map<String, dynamic>>> _recentResults = [];

//   Future<void> _processCameraImage(CameraImage image) async {
//     if (_isDetecting) return;
//     _isDetecting = true;
//     _cameraImage = image;

//     try {
//       final results = await _vision.yoloOnFrame(
//         bytesList: image.planes.map((p) => p.bytes).toList(),
//         imageHeight: image.height,
//         imageWidth: image.width,
//         confThreshold: 0.7,
//         classThreshold: 0.7,
//       );

//       setState(() => _yoloResults = results);
//       _yoloResultsStreamController.add(_yoloResults);

//       // Add to recent results
//       _recentResults.add(results);

//       // Keep only last 10 results
//       if (_recentResults.length > 20) {
//         _recentResults.removeAt(0);
//       }

//       if (_recentResults.length == 20) {
//         final bestResult = _analyzeRecentResults(_recentResults);
//         final reading = assembleMeterReading(bestResult);
//         log('Final Meter Reading: $reading');
//       }
//     } catch (e) {
//       log('Detection error: $e');
//     } finally {
//       _isDetecting = false;
//     }
//   }

//   String assembleMeterReading(List<Map<String, dynamic>> detections) {
//     // Sort left-to-right by box x1
//     detections.sort((a, b) => a['box'][0].compareTo(b['box'][0]));
//     return detections.map((d) => d['tag'].toString()).join('');
//   }

//   List<Map<String, dynamic>> _analyzeRecentResults(
//     List<List<Map<String, dynamic>>> recentResults,
//   ) {
//     // Step 1: Count how many times each digit length appears
//     final Map<int, int> lengthFrequency = {};
//     for (var result in recentResults) {
//       int length = result.length;
//       lengthFrequency[length] = (lengthFrequency[length] ?? 0) + 1;
//     }

//     // Step 2: Find the most frequent digit length
//     int mostCommonLength =
//         lengthFrequency.entries.reduce((a, b) => a.value > b.value ? a : b).key;

//     // Step 3: Filter only the results that match the most common digit length
//     List<List<Map<String, dynamic>>> matchingResults =
//         recentResults
//             .where((result) => result.length == mostCommonLength)
//             .toList();

//     // Step 4: Pick the one with the highest average confidence
//     matchingResults.sort((a, b) {
//       double avgA =
//           a.map((d) => d['box'][4] as double).reduce((x, y) => x + y) /
//           a.length;
//       double avgB =
//           b.map((d) => d['box'][4] as double).reduce((x, y) => x + y) /
//           b.length;
//       return avgB.compareTo(avgA); // sort descending
//     });

//     return matchingResults.first;
//   }

//   /// Converts the Y plane of [CameraImage] to a grayscale [img.Image]
//   img.Image _convertCameraImage(CameraImage ci) {
//     final width = ci.width;
//     final height = ci.height;
//     final img.Image imgBuffer = img.Image(width: width, height: height);
//     final plane = ci.planes[0];
//     final bytes = plane.bytes;
//     int index = 0;
//     for (int y = 0; y < height; y++) {
//       for (int x = 0; x < width; x++) {
//         final luma = bytes[index++];
//         imgBuffer.setPixelRgba(x, y, luma, luma, luma, 255);
//       }
//     }
//     return imgBuffer;
//   }

//   /// Crops [box] area from [base] image, adds padding, and returns PNG bytes
//   Uint8List _cropRaw(img.Image base, List<dynamic> box, {int padding = 10}) {
//     final int x = ((box[0] as double) - padding).clamp(0, base.width).toInt();
//     final int y = ((box[1] as double) - padding).clamp(0, base.height).toInt();
//     final int w =
//         ((box[2] as double) - (box[0] as double) + 2 * padding)
//             .clamp(0, base.width - x)
//             .toInt();
//     final int h =
//         ((box[3] as double) - (box[1] as double) + 2 * padding)
//             .clamp(0, base.height - y)
//             .toInt();
//     final img.Image crop = img.copyCrop(base, x: x, y: y, width: w, height: h);
//     return Uint8List.fromList(img.encodePng(crop));
//   }

//   img.Image _orientRawImage(img.Image raw) {
//     // 1) rotate by the sensor orientation
//     final angle = _cameraController.description.sensorOrientation;
//     img.Image rotated = img.copyRotate(raw, angle: angle);

//     // 2) if front camera, flip horizontally
//     if (_cameraController.description.lensDirection ==
//         CameraLensDirection.front) {
//       rotated = img.flipHorizontal(rotated);
//     }
//     return rotated;
//   }

//   Future<void> _onShutterPressed() async {
//     if (_cameraImage == null || _yoloResults.isEmpty) return;

//     // build a grayscale img.Image from Y plane
//     final raw = _convertCameraImage(_cameraImage!);

//     // re-orient it _before_ cropping
//     final oriented = _orientRawImage(raw);

//     // pick the first box for demo
//     final box = _yoloResults.first['box'] as List<dynamic>;
//     final croppedBytes = _cropRaw(oriented, box, padding: 0);

//     if (!mounted) return;

//     showDialog(
//       context: context,
//       builder:
//           (_) => Dialog(
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text("Captured Image"),
//                   Image.memory(croppedBytes),
//                   Align(alignment: Alignment.center, child: Text("text")),
//                 ],
//               ),
//             ),
//           ),
//     );
//   }

//   @override
//   void dispose() {
//     _cameraController.dispose();
//     _vision.closeYoloModel();
//     _yoloResultsStreamController.close();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isInitializing) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//     return Scaffold(
//       appBar: AppBar(title: const Text('Real-time Object Detection')),
//       body: AspectRatio(
//         aspectRatio: 3 / 4,
//         child: Stack(
//           fit: StackFit.expand,
//           children: [
//             CameraPreview(_cameraController),
//             CustomPaint(
//               painter: _BoundingBoxPainter(
//                 results: _yoloResults,
//                 imageSize:
//                     _cameraController.value.previewSize != null
//                         ? Size(
//                           _cameraController.value.previewSize!.height,
//                           _cameraController.value.previewSize!.width,
//                         )
//                         : const Size(1, 1),
//                 isFrontCamera:
//                     _cameraController.description.lensDirection ==
//                     CameraLensDirection.front,
//               ),
//             ),
//             StreamBuilder(
//               stream: yoloResultsStream,
//               builder: (context, snapshot) {
//                 if (snapshot.hasError) return Text(snapshot.error.toString());
//                 return Row(
//                   children: snapshot.data!.map((e) => Text(e["tag"])).toList(),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _onShutterPressed,
//         child: const Icon(Icons.camera_alt),
//       ),
//     );
//   }
// }

// class _BoundingBoxPainter extends CustomPainter {
//   final List<Map<String, dynamic>> results;
//   final Size imageSize;
//   final bool isFrontCamera;

//   const _BoundingBoxPainter({
//     required this.results,
//     required this.imageSize,
//     this.isFrontCamera = false,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     final double scaleX = size.width / imageSize.width;
//     final double scaleY = size.height / imageSize.height;
//     final paint =
//         Paint()
//           ..color = Colors.green
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = 2;

//     for (final r in results) {
//       final List<dynamic> box = r['box'] as List<dynamic>;
//       double x1 = box[0] as double;
//       double y1 = box[1] as double;
//       double x2 = box[2] as double;
//       double y2 = box[3] as double;

//       if (isFrontCamera) {
//         final tmp = x1;
//         x1 = imageSize.width - x2;
//         x2 = imageSize.width - tmp;
//       }

//       final rect = Rect.fromLTRB(
//         x1 * scaleX,
//         y1 * scaleY,
//         x2 * scaleX,
//         y2 * scaleY,
//       );
//       canvas.drawRect(rect, paint);

//       final String label = r['tag'] as String;
//       final double conf = (box[4] as double) * 100;
//       final textPainter = TextPainter(
//         text: TextSpan(
//           text: '$label ${conf.toStringAsFixed(1)}%',
//           style: const TextStyle(
//             color: Colors.white,
//             backgroundColor: Colors.black54,
//             fontSize: 12,
//           ),
//         ),
//         textDirection: TextDirection.ltr,
//       )..layout();
//       textPainter.paint(
//         canvas,
//         Offset(rect.left, rect.top - textPainter.height),
//       );
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }
