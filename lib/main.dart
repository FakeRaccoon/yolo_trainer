import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const YoloExampleApp());
}

class YoloExampleApp extends StatelessWidget {
  const YoloExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Yolo Plugin Example', home: HomeScreen());
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YOLO Plugin Example')),
      body: Center(
        child: ElevatedButton(
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CameraInferenceScreen(),
                ),
              ),
          child: const Text('Camera Inference'),
        ),
      ),
    );
  }
}

class CameraInferenceScreen extends StatefulWidget {
  const CameraInferenceScreen({super.key});

  @override
  State<CameraInferenceScreen> createState() => _CameraInferenceScreenState();
}

class _CameraInferenceScreenState extends State<CameraInferenceScreen> {
  late final YOLO _yolo;
  late final CameraController _cameraController;
  bool _modelLoaded = false;
  List<Detection> _detections = [];

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    // initialize camera
    _cameraController = CameraController(cameras[0], ResolutionPreset.high);
    await _cameraController.initialize();

    // load YOLO model
    _yolo = YOLO(modelPath: 'latest_model.tflite', task: YOLOTask.detect);

    await _yolo.loadModel();
    setState(() => _modelLoaded = true);

    // start image stream
    _cameraController.startImageStream(_processCameraImage);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_modelLoaded) return;
    // convert YUV420 to RGB bytes

    final bytesList = image.planes.first.bytes;

    final results = await _yolo.predict(bytesList);

    log("RESULT $results");
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized || !_modelLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Inference')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController),
          CustomPaint(
            painter: _DetectionPainter(
              detections: _detections,
              imageSize: Size(
                _cameraController.value.previewSize!.height,
                _cameraController.value.previewSize!.width,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Detection {
  final double x, y, w, h, confidence;
  final String label;
  Detection(this.x, this.y, this.w, this.h, this.confidence, this.label);
}

class _DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final Size imageSize;
  _DetectionPainter({required this.detections, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    for (var d in detections) {
      final rect = Rect.fromLTWH(
        d.x * scaleX,
        d.y * scaleY,
        d.w * scaleX,
        d.h * scaleY,
      );
      canvas.drawRect(rect, paint);
      final tp = TextPainter(
        text: TextSpan(
          text: '${d.label} ${(d.confidence * 100).toStringAsFixed(1)}%',
          style: const TextStyle(color: Colors.green, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left, rect.top - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
