import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';

const bool enableGemini = false;

var doodleCounter = 0;
var wakeup = false;

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
  String _question = '';
  String _lastWords = '';
  Timer? _silenceTimer;
  bool wakeup = false;

  @override
  void initState() {
    super.initState();
    print('print env variables');
    print(dotenv.env.toString());
    if (enableGemini) {
      Gemini.init(
          apiKey: dotenv.env['GOOGLE_API_KEY'] ?? '', enableDebugging: true);
    }

    controller = CameraController(
      widget.camera,
      ResolutionPreset.max,
    );

    initializeControllerFuture = controller.initialize();
    _initSpeech();
    _initiPorcupine();
    tts = FlutterTts(); // Initialize TTS
  }

  Future<void> _initSpeech() async {
    _speechToText = stt.SpeechToText();
    _speechEnabled = await _speechToText.initialize();
    if (_speechEnabled) {
      _startListening();
    }
    setState(() {});
  }

  void _initiPorcupine() async {
    try {
      print('enable porcupine in');
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        dotenv.env['PORCUPIN_API_KEY'] ?? '',
        ["assets/doodle_en_ios_v3_0_0.ppn"],
        _wakeWordCallback,
      );

      await _porcupineManager?.start();
    } on PorcupineException catch (err) {
      // Handle initialization error
      print('Failed to initialize Porcupine: ${err.message}');
    }
  }

  Future<void> _getGeminiResponse(question) async {
    final gemini = Gemini.instance;

    var result = "";
    // gemini.textAndImage(
    //   text: _lastWords,
    //   images: [selectedImage.readAsBytesSync()],
    // ).then((value) {
    //   log('Got the response...');

    //   // Check if the response is not null and has output
    //   if (value != null && value.output != null) {
    //     results = value.output!;
    //   }
    // };

    var prompt =
        "Pretend you are talking to a 4-8 years old child, answer the following question in simple words, keep the conversation playful and engaging by asking a leading question " +
            question;
    print(prompt);
    gemini.text(prompt).then((value) {
      String results = "Show results here...";
      results = value!.output!;
      _speak(results);
    }).catchError((e) => print(e));
  }

  Future<void> _speak(text) async {
    await tts.setLanguage("en-US");
    await tts.setPitch(1.0);
    await tts.speak(text);
  }

  void _wakeWordCallback(int keywordIndex) {
    if (keywordIndex == 0) {
      // Custom wake word detected
      print('<==========Inside the Wake word detected =======>');
      print(doodleCounter++);
      wakeup = true;
      _startSilenceTimer();
      _question = "";
    }
  }

  void _startListening() {
    _speechToText.listen(
      onResult: (val) {
        setState(() {
          _lastWords = val.recognizedWords;
        });

        // Reset the silence timer if speech is detected
        _resetSilenceTimer();

        // Call _speak here to convert the recognized words to speech
        // _speak(_lastWords); // Example text
      },
    );
  }

  void _startSilenceTimer() {
    _silenceTimer?.cancel(); // Cancel any existing timer
    _silenceTimer = Timer(Duration(microseconds: 5000), () {
      // This block will execute after 1 second of silence
      print(_lastWords);
      var i = _lastWords.toLowerCase().indexOf('doodle');

      if (i > 0) {
        var ask = _lastWords.substring(i, _lastWords.length - 1);
        print('<------ ask this ------>');
        print(i);
        print(ask);
      }
    });
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel(); // Cancel the timer if speech is detected
  }
  // void _handleSpeech() async {
  //   if (!_speechToText.isListening) {
  //     bool available = await _speechToText.initialize(
  //       onStatus: (val) => print('onStatus: $val'),
  //       onError: (val) => print('onError: $val'),
  //     );
  //     print('available: $available');
  //     if (available) {
  //       _speechToText.listen(
  //         onResult: (val) {
  //           setState(() {
  //             print('2 <---------Inside the Wake word detected-------->');

  //             _lastWords = val.recognizedWords;
  //             print(val.recognizedWords);
  //           });
  //         },
  //       );
  //     }
  //   }
  //   setState(() {});
  // }

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
                Positioned(
                  bottom: 0, // Adjust as needed
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    color: Colors.black54,
                    child: Text(
                      // _lastWords.length > 60
                      //     ? _lastWords.substring(
                      //         _lastWords.length - 60, _lastWords.length)
                      //     : _lastWords,
                      _lastWords,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
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
