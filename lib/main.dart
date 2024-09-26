import 'dart:developer';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:async';
import 'package:image/image.dart' as dartImage;
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'rectangle_painter.dart'; // Adjust the path if necessary

const wakeStart = "hey buddy";
const wakeEnd = "tell me";

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();

  // Get the front camera
  CameraDescription frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
  );

  await dotenv.load(fileName: ".env");

  runApp(MyApp(camera: frontCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraScreen(camera: camera),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> initializeControllerFuture;
  late Interpreter _interpreter;
  String _currentTime = ''; // Variable to hold current time

  final int numClasses =
      5; // Change this to the number of fruit classes your model can detect
  final List<String> classNames = [
    'Apple',
    'Banana',
    'Orange',
    'Mango',
    'Lemon',
    // Add more fruit names as per your model's output
  ];

  @override
  void initState() {
    super.initState();

    Gemini.init(
        apiKey: dotenv.env['GOOGLE_API_KEY'] ?? '', enableDebugging: true);

    _controller = CameraController(
      widget.camera,
      ResolutionPreset.max,
    );

    initializeControllerFuture = _controller.initialize();
    _initFruitsModel();

    initializeControllerFuture.then((_) {
      if (_controller.value.isInitialized) {
        _controller.startImageStream((CameraImage image) {
          // _processCameraImage(image);
        });
      }
    }).catchError((error) {
      print('Error initializing camera: $error');
    });
  }

  List<dynamic> voices = [];

  Future<void> _initFruitsModel() async {
    _interpreter = await Interpreter.fromAsset('assets/fruits_model.tflite');
  }

  @override
  void dispose() {
    _controller.dispose();
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Scaffold(
            body: Stack(
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: CameraPreview(_controller),
                  ),
                ),
                // Custom painter to draw the rectangle
                CustomPaint(
                  size: Size(MediaQuery.of(context).size.width,
                      MediaQuery.of(context).size.height),
                  painter: RectanglePainter(),
                ),
              ],
            ),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
