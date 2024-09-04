import 'dart:convert';
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
import 'text_to_speach.dart';
import 'package:http/http.dart' as http;

const wakeStart = "hey buddy";
const wakeEnd = "tell me";

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
  final TextToSpeech _textToSpeech = TextToSpeech();

  bool _speechEnabled = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();

    tts = FlutterTts();

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
        "Pretend you are talking to a 4-8 years old child, answer the following question in simple words, keep the conversation playful and engaging by asking a leading question \n\n\n" +
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

    gemini.textAndImage(
      text: prompt,
      images: [await image.readAsBytesSync()],
    ).then((value) {
      if (value != null && value.output != null) {
        String results = value.output!;
        print('Image description: ' + results);
        _speak(results);
      }
    });
  }

  Future<void> _speakText(text) async {
    print('<====== audio response in _speakText ========>');

    var headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    // 'https://texttospeech.googleapis.com/v1/text:synthesize?key=AIzaSyDyD3Cl845NiAT-lohwsnN_725KC7Q9GAg'

    var request = http.Request(
        'POST',
        Uri.parse(
            'https://texttospeech.googleapis.com/v1/text:synthesize?key=${dotenv.env['GCP_API_KEY']}'));
    request.body = json.encode({
      "input": {"text": "Hello, this is a test."},
      "voice": {
        "languageCode": "en-US",
        "name": "en-US-Wavenet-F",
        "ssmlGender": "FEMALE"
      },
      "audioConfig": {"audioEncoding": "MP3"}
    });
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      print(await response.stream.bytesToString());
    } else {
      print(response.reasonPhrase);
    }
  }

  void _speak_new(text) {
    if (text.isNotEmpty) {
      _textToSpeech.speak(text);
    }
  }

  Future<void> _speak(text) async {
    voices = await tts.getVoices;
    // await tts.setLanguage("en-US");
    // await tts.setPitch(1.0);
    // await tts.speak(text);
    await _speakText(text);
  }

  void _wakeWordCallback(int keywordIndex) async {
    print('<---- wake up ---->');
    switch (keywordIndex) {
      case 0:
        print('<---- hey buddy ---->');
        break;
      case 1:
        print('<---- tell me ---->');
        print(_lastWords);
        var lastIndex = _lastWords.toLowerCase().lastIndexOf(wakeStart);
        if (lastIndex > 0 - 1) {
          var question = _lastWords.substring(lastIndex + wakeStart.length);
          print(question);
          _getGeminiTextResponse(question);
        }
        break;
      case 2:
        print('<---- what do you see ---->');
        await controller.takePicture().then((value) {
          if (value != null) {
            File image = File(value.path);
            _getGeminiImageResponse(image);
          }
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
