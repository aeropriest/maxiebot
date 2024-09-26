// https://stackoverflow.com/questions/78043904/interpreter-returned-output-of-shape-1-2-while-shape-of-output-provided-as-a
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'rectangle_painter.dart'; // Adjust the path if necessary

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
  }

  List<dynamic> voices = [];

  Future<void> _initFruitsModel() async {
    // _interpreter = await Interpreter.fromAsset('assets/fruits_model.tflite');
    _interpreter = await Interpreter.fromAsset('assets/arrow_model.tflite');
  }

  Future<void> _takeSnapshotAndDetectObjects() async {
    print('Look for fruits model');
    try {
      // Take a picture
      final value = await _controller.takePicture();
      File image = File(value.path);

      print('Picture taken: ${value.path}');
      final imageDataBytes = await image.readAsBytes();
      img.Image? imageData = img.decodeImage(imageDataBytes);

      if (imageData == null) {
        print('Failed to decode image data');
        return;
      }

      // Log image properties
      // print('Image Width: ${imageData.width}');
      // print('Image Height: ${imageData.height}');
      // print('Image Format: ${imageData.format}');

      // Resize or preprocess the image if necessary
      // For example, if your model expects 224x224 images:
      img.Image resizedImage =
          img.copyResize(imageData, width: 224, height: 224);

      var output = {
        0: [List<num>.filled(2, 0)]
      };

      // var output = List.filled(numClasses, 0).reshape(
      //     [1, numClasses]); // Adjust shape based on your model's output

      // // Pass the resized image to the interpreter
      // _interpreter.run(resizedImage.getBytes(),
      //     output); // Ensure resizedImage is in the correct format

      print('Run the interpreter');
      print(_interpreter.getOutputTensors());
      print('Detection results: $output');
    } catch (e) {
      print('Error taking snapshot or detecting objects: $e');
    }
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
                // CustomPaint(
                //   size: Size(MediaQuery.of(context).size.width,
                //       MediaQuery.of(context).size.height),
                //   painter: RectanglePainter(),
                // ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _takeSnapshotAndDetectObjects,
              tooltip: 'Take Snapshot',
              child: Icon(Icons.camera_alt),
            ),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
