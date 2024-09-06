import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';

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
    _initSpeechToText();
    _initPorcupine();
    _initTextToSpeech();
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

  Future<void> _getGeminiImageResponse(image) async {
    final gemini = Gemini.instance;
    var prompt =
        "Pretend you are talking to a 4-8 years old child, look at the below drawing and tell a engaging, funny story of what you see in simple words, keep the conversation short, playful and engaging by asking a leading question ";

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
        // print(_lastWords);
        var lastIndex = _lastWords.lastIndexOf(wakeStart);
        if (lastIndex > 0 - 1) {
          print('<========== what do you see =======>');
          var question = _lastWords.substring(lastIndex + wakeStart.length);
          print(question);
          _getGeminiTextResponse(question);
        }
        break;
      case 2:
        await _controller.takePicture().then((value) {
          File image = File(value.path);
          print('--------------------------------');
          print(value.path);
          _getGeminiImageResponse(image);
        });

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
