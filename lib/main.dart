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
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:o3d/o3d.dart';

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
  late stt.SpeechToText _speechToText;
  late FlutterTts _textToSpeech; // Initialize Flutter TTS
  late PorcupineManager? _porcupineManager;
  late TextRecognizer textRecognizer;
  late Interpreter _interpreter;
  final O3DController o3dController = O3DController();

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
  bool _speechEnabled = false;
  String _lastWords = '';

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
    textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _initSpeechToText();
    _initPorcupine();
    _initTextToSpeech();
    _initImageDetection();

    initializeControllerFuture.then((_) {
      if (_controller.value.isInitialized) {
        _controller.startImageStream((CameraImage image) {
          _processCameraImage(image);
        });
      }
    }).catchError((error) {
      print('Error initializing camera: $error');
    });
  }

  void _processCameraImage(CameraImage image) async {
    print('processing image...');
    // Convert and preprocess the image as needed
    var inputImage = _preprocessImage(image);

    // Run inference
    var output = List.filled(1 * numClasses, 0).reshape([1, numClasses]);

    // print(output.join());
    _interpreter.run(image, output);

    // // Example: Get the detected fruit class
    int detectedClass = output[0].indexOf(output[0].reduce(max));
    String fruitName = classNames[detectedClass]; // Map index to class name
    print('Detected fruit: $fruitName');
  }

  Uint8List _preprocessImage(CameraImage image) {
    // Get the image dimensions
    int width = image.width;
    int height = image.height;

    // Convert the CameraImage to a format compatible with your model
    // Assuming the model expects a 300x300 RGB image
    int targetWidth = 300;
    int targetHeight = 300;

    // Convert YUV420 to RGB
    // The CameraImage format is typically YUV420
    // Create an image buffer
    dartImage.Image convertedImage =
        dartImage.Image(width: targetWidth, height: targetHeight);

    // Convert YUV420 to RGB
    // YUV420 format: Y plane followed by U and V planes
    // We will use the Y plane to get the brightness and then average U and V for color
    // Convert YUV420 to RGB
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Get the Y value
        int yIndex = y * width + x;
        int yValue = image.planes[0].bytes[yIndex];

        // Get the U and V values
        int uIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);
        int vIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

        int uValue = image.planes[1].bytes[uIndex] - 128;
        int vValue = image.planes[2].bytes[vIndex] - 128;

        // Convert YUV to RGB
        int r = (yValue + 1.402 * vValue).clamp(0, 255).toInt();
        int g = (yValue - 0.344136 * uValue - 0.714136 * vValue)
            .clamp(0, 255)
            .toInt();
        int b = (yValue + 1.772 * uValue).clamp(0, 255).toInt();

        // Set the pixel in the converted image
        // convertedImage.setPixel(x, y, dartImage.getColor(r, g, b));
      }
    }

    // Resize the image to the target size
    dartImage.Image resizedImage = dartImage.copyResize(convertedImage,
        width: targetWidth, height: targetHeight);

    // Convert the resized image to a Uint8List
    Uint8List imageBytes =
        Uint8List.fromList(dartImage.encodeJpg(resizedImage));

    // Normalize the pixel values to [0, 1] range if required by your model
    // This step depends on your model's expected input
    // Here we assume the model expects float32 input
    Float32List normalizedBytes = Float32List(targetWidth * targetHeight * 3);
    for (int i = 0; i < imageBytes.length; i++) {
      normalizedBytes[i] = imageBytes[i] / 255.0; // Normalize to [0, 1]
    }

    return normalizedBytes.buffer.asUint8List();
  }

  List<dynamic> voices = [];

  Future<void> _initImageDetection() async {
    print('Initializing image detection model from tensorflow lite');
    _interpreter = await Interpreter.fromAsset('assets/fruits_model.tflite');
    final isolateInterpreter =
        await IsolateInterpreter.create(address: _interpreter.address);
  }

  Future<void> _initTextToSpeech() async {
    print('Initializing text to speech');
    _textToSpeech = FlutterTts(); // Initialize TTS
    voices = await _textToSpeech.getVoices;
    voices = voices.where((voice) => voice['name'].contains('en')).toList();
    setState(() {});
  }

  Future<void> _initSpeechToText() async {
    print('Initializing speech to text');
    _speechToText = stt.SpeechToText();
    _speechEnabled = await _speechToText.initialize();
    if (_speechEnabled) {
      _startListening();
    }
    setState(() {});
  }

  void _initPorcupine() async {
    print('Initializing _initPorcupine');
    try {
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        dotenv.env['PORCUPIN_API_KEY'] ?? '',
        [
          "assets/hey-buddy_en_ios_v3_0_0.ppn",
          "assets/tell-me_en_ios_v3_0_0.ppn",
          "assets/what-do-you-see_en_ios_v3_0_0.ppn"
        ],
        _wakeWordCallback,
      );

      await _porcupineManager?.start();
    } on PorcupineException catch (err) {
      // Handle initialization error
      print('Failed to initialize Porcupine: ${err.message}');
    }
  }

  Future<void> _getGeminiTextResponse(question) async {
    final gemini = Gemini.instance;
    var prompt =
        "Pretend you are talking to a 4-8 years old child, answer the following question in simple words, keep the conversation playful and engaging by asking a leading question " +
            question;
    print(prompt);
    gemini.text(prompt).then((value) {
      String results = "Show results here...";
      results = value!.output!;
      _speak(results);
    }).catchError(
        (e) => print('<-!!!!  error in gemini query !!!!->' + e.message));
  }

  Future<void> _getGeminiImageResponse(image, text, question) async {
    final gemini = Gemini.instance;
    var prompt =
        'Pretend you are talking to a 4-8 years old child, look at the below drawing as well as text and tell a engaging, funny story of what you see in simple words, keep the conversation short, playful and engaging by asking a leading question \n\n $question \n\n\n $text';
    // var prompt =
    //     "Pretend you are talking to a 4-8 years old child, look at the below drawing as well as text and tell a engaging, funny story of what you see in simple words, keep the conversation short, playful and engaging by asking a leading question \n\n" +
    //         text;

    print('<===== prompt is =====>');
    print(prompt);
    gemini.textAndImage(
      text: prompt,
      images: [await image.readAsBytesSync()],
    ).then((value) {
      if (value != null && value.output != null) {
        String results = value.output!;
        print('Image description: $results');
        _speak(results);
      }
    });
  }

  Future<void> _speak(text) async {
    voices = await _textToSpeech.getVoices;
    // await _textToSpeech.setLanguage("en-US");
    // await _textToSpeech.setPitch(1.0);
    await _textToSpeech.speak(text);
  }

  void _wakeWordCallback(int keywordIndex) async {
    switch (keywordIndex) {
      case 0:
        print('<========== Hey Buddy Wake Up =======>');
        break;
      case 1:
        print('<========== Tell Me =======>');
        var lastIndex = _lastWords.lastIndexOf(wakeStart);
        if (lastIndex > -1) {
          var question = _lastWords.substring(lastIndex + wakeStart.length);
          print(question);
          await _getGeminiTextResponse(
              question); // Added await for async function
        }
        break;
      case 2:
        // Simplified condition
        print('<========== what do you see =======>');
        try {
          final value =
              await _controller.takePicture(); // Use await instead of then
          File image = File(value.path);

          // Read image bytes asynchronously
          final imageDataBytes = await image.readAsBytes();
          dartImage.Image imageData =
              dartImage.decodeImage(imageDataBytes) as dartImage.Image;

          dartImage.Image mirrorImage = dartImage.flipHorizontal(imageData);

          // Write the mirror image bytes to the file
          await image.writeAsBytes(dartImage.encodeJpg(mirrorImage));

          InputImage inputImage = InputImage.fromFile(image);
          final result = await textRecognizer
              .processImage(inputImage); // Use await for processImage
          print('Text found is: ${result.text}');
          var question = "explain this to me";
          await _getGeminiImageResponse(image, result.text, question);
        } catch (e) {
          print('Error processing image: $e'); // Handle errors
        }
        break;
      default:
        print(
            'Unknown keyword index: $keywordIndex'); // Handle unexpected cases
        break;
    }
  }

  void _startListening() {
    _speechToText.listen(
      onResult: (val) {
        setState(() {
          _lastWords = val.recognizedWords;
        });
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _speechToText.stop();
    _porcupineManager?.stop();
    _porcupineManager?.delete();
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
                Positioned(
                  top: (MediaQuery.of(context).size.height / 2) -
                      100, // Adjust the position as needed
                  left: (MediaQuery.of(context).size.width / 2) -
                      100, // Adjust the position as needed
                  child: SizedBox(
                    width: 400, // Set the width of the model viewer
                    height: 400, // Set the height of the model viewer
                    child: O3D.asset(
                      src: 'assets/disney_style_character.glb',
                      controller: o3dController,
                      ar: false,
                      autoPlay: true,
                      autoRotate: false,
                      cameraControls: false,
                      cameraTarget: CameraTarget(-.25, 1.5, 1.5),
                      cameraOrbit: CameraOrbit(0, 90, 1),
                    ),
                  ),
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
