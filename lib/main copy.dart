// import 'dart:async';
// import 'dart:developer';
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:ocr/converter.dart';
// import 'package:ultralytics_yolo/yolo.dart';
// import 'package:ultralytics_yolo/yolo_view.dart';

// late List<CameraDescription> cameras;

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   cameras = await availableCameras();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(theme: ThemeData.dark(), home: const CameraHome());
//   }
// }

// class CameraHome extends StatefulWidget {
//   const CameraHome({Key? key}) : super(key: key);

//   @override
//   _CameraHomeState createState() => _CameraHomeState();
// }

// class _CameraHomeState extends State<CameraHome> {
//   late CameraController _cameraController;
//   bool _isInitializing = true;
//   bool _isDetecting = false;
//   late YOLO _yolo;

//   CameraImage? _cameraImage;
//   List<Map<String, dynamic>> _yoloResults = [];

//   // store original preview size
//   Size _previewSize = const Size(1, 1);

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

//   @override
//   void dispose() {
//     _cameraController.dispose();
//     super.dispose();
//   }

//   Future<void> _initializeCamera() async {
//     _yolo = YOLO(modelPath: 'assets/new_model.tflite', task: YOLOTask.detect);
//     await _yolo.loadModel();

//     await _cameraController.initialize();
//     _previewSize = Size(
//       _cameraController.value.previewSize!.height,
//       _cameraController.value.previewSize!.width,
//     );
//     // _vision = FlutterVision();
//     // await _vision.loadYoloModel(
//     //   labels: 'assets/label_meter.txt',
//     //   modelPath: 'assets/latest_model.tflite',
//     //   modelVersion: 'yolov8',
//     // );
//     _cameraController.startImageStream(_processCameraImage);
//     setState(() => _isInitializing = false);
//   }

//   Future<void> _processCameraImage(CameraImage image) async {
//     if (_isDetecting) return;
//     _isDetecting = true;
//     try {
//       // final results = await _vision.yoloOnFrame(
//       //   bytesList: image.planes.map((p) => p.bytes).toList(),
//       //   imageHeight: image.height,
//       //   imageWidth: image.width,
//       // );
//       setState(() {
//         _cameraImage = image;
//         // _yoloResults = results;
//       });
//     } catch (e) {
//       log('Detection error: $e');
//     } finally {
//       _isDetecting = false;
//     }
//   }

//   // Future<void> _onShutterPressed() async {
//   //   if (_cameraImage == null || _yoloResults.isEmpty) return;

//   //   final raw = FlutterImageUtils.convertYUV420ToImage(
//   //     _cameraImage!,
//   //     cameraDescription: _cameraController.description,
//   //   );

//   //   // crop to first detected box
//   //   final first = _yoloResults.first;
//   //   final cropped = FlutterImageUtils.cropImageFromBox(raw, first['box']);
//   //   final result = await _yolo.predict(cropped);

//   //   if (!mounted) return;

//   //   log('Detection complete: $result objects detected', name: 'Detection');

//   //   // show full-resolution annotated image + overlay list
//   //   showAnalysisDialog(
//   //     context,
//   //     Size(raw.width.toDouble(), raw.height.toDouble()),
//   //   );
//   // }

//   @override
//   Widget build(BuildContext context) {
//     if (_isInitializing) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//     return Scaffold(
//       appBar: AppBar(title: const Text('Real-time Object Detection')),
//       body: AspectRatio(
//         aspectRatio: _previewSize.width / _previewSize.height,
//         child: Stack(
//           fit: StackFit.expand,
//           children: [
//             CameraPreview(_cameraController),
//             CustomPaint(
//               painter: _BoundingBoxPainter(
//                 results: _yoloResults,
//                 imageSize: _previewSize,
//                 isFrontCamera:
//                     _cameraController.description.lensDirection ==
//                     CameraLensDirection.front,
//               ),
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {},
//         child: const Icon(Icons.camera_alt),
//       ),
//     );
//   }
// }

// // painter for live preview boxes
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
//     final scaleX = size.width / imageSize.width;
//     final scaleY = size.height / imageSize.height;
//     final paint =
//         Paint()
//           ..color = Colors.green
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = 2;

//     for (var r in results) {
//       var box = r['box'] as List<dynamic>;
//       double x1 = box[0], y1 = box[1], x2 = box[2], y2 = box[3];
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
//       final label = r['tag'] as String;
//       final conf = (r['box'][4] as double) * 100;
//       final tp = TextPainter(
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
//       tp.paint(canvas, Offset(rect.left, rect.top - tp.height));
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter old) => true;
// }

// void showAnalysisDialog(BuildContext context, Size imageSize) {
//   final maxHeight = MediaQuery.of(context).size.height * 0.8;
//   final maxWidth = MediaQuery.of(context).size.width * 0.9;

//   showDialog<void>(
//     context: context,
//     builder:
//         (_) => Dialog(
//           insetPadding: const EdgeInsets.all(16),
//           child: Container(
//             constraints: BoxConstraints(
//               maxHeight: maxHeight,
//               maxWidth: maxWidth,
//             ),
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               children: [
//                 Text('Analysis Result'),
//                 const SizedBox(height: 12),

//                 // Image section
//                 YoloView(
//                   task: YOLOTask.detect,
//                   // Use model name only - recommended approach for cross-platform compatibility
//                   modelPath: 'assets/newest_model.tflite',
//                   onResult: (results) {
//                     // Handle detection results
//                     print('Detected ${results.length} objects');
//                   },
//                 ),
//                 const SizedBox(height: 16),

//                 // Actions
//                 Align(
//                   alignment: Alignment.centerRight,
//                   child: TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text('OK'),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//   );
// }
