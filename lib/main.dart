import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  bool _speechEnabled = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    controller = CameraController(
      widget.camera,
      ResolutionPreset.max,
    );
    initializeControllerFuture = controller.initialize();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechToText = stt.SpeechToText();
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _handleSpeech() async {
    _speechToText.isListening
        ? print('speech is listening')
        : print('speech is not listening');
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
              _lastWords = val.recognizedWords;
            });
            if (_lastWords.toLowerCase().contains('hey maxie')) {
              // Perform action when wake word is detected
              print("Wake word detected!");
            }
          },
        );
      }
    } else {
      print('listen mode');
      _speechToText.listen(
        onResult: (val) {
          setState(() {
            _lastWords = val.recognizedWords;
            print(_lastWords.toString());
          });
          if (_lastWords.toLowerCase().contains('hey maxie')) {
            // Perform action when wake word is detected
            print("Wake word detected!");
          }
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
                // Circular Microphone Button
                Positioned(
                  bottom: 40,
                  left: MediaQuery.of(context).size.width / 2 -
                      35, // Center the button
                  child: GestureDetector(
                    onTap: () {
                      _speechEnabled
                          ? print('speech is enabled')
                          : print('speech is disabled');
                      if (_speechEnabled) _handleSpeech();
                    },
                    child: Container(
                      width: 70, // Width of the circular button
                      height: 70, // Height of the circular button
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
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
