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
// import 'package:gallery_saver/gallery_saver.dart';

const wakeStart = "hey buddy";
const wakeEnd = "tell me";
bool _isSpeaking = false;

PorcupineManager? _porcupineManager;

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

  const CameraApp({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraScreen(camera: camera),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController controller;
  late Future<void> initializeControllerFuture;
  late stt.SpeechToText _speechToText;
  late FlutterTts tts; // Initialize Flutter TTS

  bool _speechEnabled = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    print(dotenv.env.toString());
    Gemini.init(
        apiKey: dotenv.env['GOOGLE_API_KEY'] ?? '', enableDebugging: true);

    controller = CameraController(
      widget.camera,
      ResolutionPreset.max,
    );

    initializeControllerFuture = controller.initialize();
    _initSpeech();
    _initPorcupine();
    _initTTS();
  }

  List<dynamic> voices = [];

  Future<void> _initTTS() async {
    tts = FlutterTts(); // Initialize TTS
    voices = await tts.getVoices;
    // Filter voices if needed, e.g., only English voices
    voices = voices.where((voice) => voice['name'].contains('en')).toList();
    print(voices);
    var currentVoice = voices.first; // Set default voice
    // if( tts)
    // await tts.setVoice(currentVoice);
    setState(() {});
  }

  Future<void> _initSpeech() async {
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
    // print(prompt);
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

    // var prompt =
    //     "Pretend you are talking to a 4-8 years old child, read from below and tell a engaging, funny story in simple words, keep the conversation short, playful and engaging by asking a leading question ";

    gemini.textAndImage(
      text: prompt,
      images: [await image.readAsBytesSync()],
    ).then((value) {
// Check if the response is not null and has output
      if (value != null && value.output != null) {
        String results = value.output!;
        print('Image description: ' + results);
        _speak(results);
      }
    });
  }

  Future<void> _speak(text) async {
    voices = await tts.getVoices;
    // await tts.setLanguage("en-US");
    // await tts.setPitch(1.0);
    await tts.speak(text);
  }

  void _wakeWordCallback(int keywordIndex) async {
    if (keywordIndex == 0) {
      print('<========== Hey Buddy Wake Up =======>');
    }
    if (keywordIndex == 1) {
      print('<========== Tell Me =======>');
      // print(_lastWords);
      var lastIndex = _lastWords.lastIndexOf(wakeStart);
      if (lastIndex > 0 - 1) {
        print('<========== what do you see =======>');
        var question = _lastWords.substring(lastIndex + wakeStart.length);
        print(question);
        _getGeminiTextResponse(question);
      }
    }
    // tell the user what you see in the image
    if (keywordIndex == 2) {
      await controller.takePicture().then((value) {
        if (value != null) {
          File image = File(value.path);
          _getGeminiImageResponse(image);
        }
      });
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
    controller.dispose();
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
                    child: CameraPreview(controller),
                  ),
                ),
                // Positioned(
                //   bottom: 0, // Adjust as needed
                //   left: 0,
                //   right: 0,
                //   child: Container(
                //     padding: const EdgeInsets.symmetric(horizontal: 16.0),
                //     color: Colors.black54,
                //     child: Text(
                //       //   // _lastWords.length > 60
                //       //   //     ? _lastWords.substring(
                //       //   //         _lastWords.length - 60, _lastWords.length)
                //       //   //     : _lastWords,
                //       _lastWords,
                //       style: const TextStyle(
                //         color: Colors.white,
                //         fontSize: 24,
                //       ),
                //       textAlign: TextAlign.center,
                //     ),
                //   ),
                // ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: _isSpeaking ? 50.0 : 0.0,
                    color: Colors.black54,
                    child: Center(
                      child: Text(
                        'Speaking...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          );
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
