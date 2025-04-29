// import 'dart:async';
// import 'dart:developer';
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:flutter_vision/flutter_vision.dart';

// late List<CameraDescription> cameras;

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   try {
//     cameras = await availableCameras();
//     runApp(const MyApp());
//   } catch (e) {
//     log('Error initializing cameras: $e');
//   }
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
//   State<CameraHome> createState() => _CameraHomeState();
// }

// class _CameraHomeState extends State<CameraHome> {
//   late CameraController _cameraController;
//   late FlutterVision vision;
//   bool _isInitializing = true;
//   bool _isDetecting = false;
//   List<Map<String, dynamic>> _yoloResults = [];

//   @override
//   void initState() {
//     super.initState();
//     _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
//     _initializeCamera();
//   }

//   Future<void> _initializeCamera() async {
//     try {
//       await _cameraController.initialize();
//       vision = FlutterVision();
//       await vision.loadYoloModel(
//         labels: 'assets/labels.txt',
//         modelPath: 'assets/latest_model.tflite',
//         modelVersion: 'yolov8',
//       );
//       _cameraController.startImageStream(_processCameraImage);
//       setState(() => _isInitializing = false);
//     } catch (e) {
//       log('Initialization error: $e');
//       _showErrorDialog('Failed to initialize camera and model');
//     }
//   }

//   Future<void> _processCameraImage(CameraImage image) async {
//     if (_isDetecting || !mounted) return;
//     _isDetecting = true;
//     try {
//       final results = await vision.yoloOnFrame(
//         bytesList: image.planes.map((p) => p.bytes).toList(),
//         imageHeight: image.height,
//         imageWidth: image.width,
//       );
//       if (mounted) {
//         setState(() => _yoloResults = results);
//       }
//     } catch (e) {
//       log('Detection error: $e');
//     } finally {
//       _isDetecting = false;
//     }
//   }

//   void _showErrorDialog(String message) {
//     showDialog(
//       context: context,
//       builder:
//           (ctx) => AlertDialog(
//             title: const Text('Error'),
//             content: Text(message),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx),
//                 child: const Text('OK'),
//               ),
//             ],
//           ),
//     );
//   }

//   @override
//   void dispose() {
//     _cameraController.dispose();
//     vision.closeYoloModel();
//     super.dispose();
//   }

//   /// Called when the FloatingActionButton is pressed
//   Future<void> _onShutterPressed() async {
//     // Cropping logic if needed
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isInitializing) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     return Scaffold(
//       appBar: AppBar(title: const Text('Real-time Object Detection')),
//       body: Center(
//         child: AspectRatio(
//           aspectRatio: 3 / 4, // Lock preview to 3:4
//           child: Stack(
//             fit: StackFit.expand,
//             children: [
//               CameraPreview(_cameraController),
//               CustomPaint(
//                 painter: _BoundingBoxPainter(
//                   results: _yoloResults,
//                   // Swap previewSize dims for portrait orientation
//                   imageSize:
//                       _cameraController.value.previewSize != null
//                           ? Size(
//                             _cameraController.value.previewSize!.height,
//                             _cameraController.value.previewSize!.width,
//                           )
//                           : const Size(1, 1),
//                   isFrontCamera:
//                       _cameraController.description.lensDirection ==
//                       CameraLensDirection.front,
//                 ),
//               ),
//             ],
//           ),
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

//   _BoundingBoxPainter({
//     required this.results,
//     required this.imageSize,
//     this.isFrontCamera = false,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     // size == preview widget size (3:4)
//     final scaleX = size.width / imageSize.width;
//     final scaleY = size.height / imageSize.height;
//     final paint =
//         Paint()
//           ..color = Colors.red
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = 2;

//     for (final r in results) {
//       final box = r['box'] as List<dynamic>;
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

//       final label = r['tag'] as String;
//       final conf = (box[4] as double) * 100;
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
