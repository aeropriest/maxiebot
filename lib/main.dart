import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();

  // Get the front camera
  CameraDescription frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
  );

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
    Gemini.init(
        apiKey: 'AIzaSyB9sU_QRwE8hYt1lkh6vK0xBkJ5M6Tgbx8',
        enableDebugging: true);

    controller = CameraController(
      widget.camera,
      ResolutionPreset.max,
    );
    initializeControllerFuture = controller.initialize();
    _initSpeech();
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

  void _startListening() {
    _speechToText.listen(
      onResult: (val) {
        setState(() {
          print('set here 3');
          _lastWords = val.recognizedWords;
          print(_lastWords.length);
        });

        // Call _speak here to convert the recognized words to speech
        // _speak(_lastWords); // Example text
        _getGeminiResponse(_lastWords);
      },
      // Uncomment this if you want to restart listening when done
      // onDone: () {
      //   _startListening();
      // },
    );
  }

  void _handleSpeech() async {
    if (!_speechToText.isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      print('available: $available');
      if (available) {
        _speechToText.listen(
          onResult: (val) {
            setState(() {
              print('set here 1');
              _lastWords = val.recognizedWords;
            });
          },
        );
      }
    } else {
      print('listen mode');
      _speechToText.listen(
        onResult: (val) {
          setState(() {
            print('set here 2');
            _lastWords = val.recognizedWords;
          });
        },
      );
      _speechToText.stop();
    }
    setState(() {});
  }

  @override
  void dispose() {
    controller.dispose();
    _speechToText.stop();
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
                // Camera Preview
                // Camera Preview
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
