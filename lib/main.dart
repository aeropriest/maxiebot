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
import 'package:tflite/tflite.dart';

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

  runApp(CameraApp(camera: frontCamera));
}

class CameraApp extends StatelessWidget {
  final CameraDescription camera;

  const CameraApp({super.key, required this.camera});

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
  late List<dynamic> _recognitions = []; // Store recognitions

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
    loadCoinDetectionModel();
  }

  loadCoinDetectionModel() async {
    String? res = await Tflite.loadModel(
      model: "assets/coin_detection_model.tflite",
    );
    print(res);
  }

  Future<void> _detectCoins(CameraImage image) async {
    // Convert CameraImage to the format required by TFLite
    // You may need to implement this conversion based on your model requirements

    // Run the model on the image
    var recognitions = await Tflite.runModelOnFrame(
      bytesList: image.planes.map((plane) => plane.bytes).toList(),
      imageHeight: image.height,
      imageWidth: image.width,
      numResults: 3,
      threshold: 0.5,
    );

    setState(() {
      _recognitions = recognitions!; // Update recognitions
    });
  }

  List<dynamic> voices = [];

  Future<void> _initTextToSpeech() async {
    _textToSpeech = FlutterTts(); // Initialize TTS
    voices = await _textToSpeech.getVoices;
    voices = voices.where((voice) => voice['name'].contains('en')).toList();
    setState(() {});
  }

  Future<void> _initSpeechToText() async {
    _speechToText = stt.SpeechToText();
    _speechEnabled = await _speechToText.initialize();
    if (_speechEnabled) {
      _startListening();
    }
    setState(() {});
  }

  void _initPorcupine() async {
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
                // Overlay for detected coins
                ..._recognitions.map((recognition) {
                  final rect = recognition[
                      'rect']; // Assuming your model returns a 'rect' field
                  return Positioned(
                    left: rect['x'] * MediaQuery.of(context).size.width,
                    top: rect['y'] * MediaQuery.of(context).size.height,
                    child: Container(
                      width: rect['w'] * MediaQuery.of(context).size.width,
                      height: rect['h'] * MediaQuery.of(context).size.height,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: Center(
                        child: Icon(
                          // Use different icons based on the recognized coin
                          recognition['label'] == '1 dollar'
                              ? Icons.attach_money
                              : recognition['label'] == '2 dollar'
                                  ? Icons.money_off
                                  : recognition['label'] == '5 dollar'
                                      ? Icons.monetization_on
                                      : null,
                          size: 30,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
