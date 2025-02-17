import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:meta/meta.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Gemini.init(apiKey: dotenv.env['GEMINI_API_KEY']!);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maxie Bot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Hi ! I am Maxie..'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _voiceText = '';
  bool _speechEnabled = false;
  final ValueNotifier<bool> _isTextToSpeechEnabled = ValueNotifier<bool>(false);
  bool isTextToSpeechEnabled = false; // Track text-to-speech state

  @override
  void initState() {
    super.initState();
    _initSpeechToText();
  }

  Future<void> _initSpeechToText() async {
    _speechToText = stt.SpeechToText();
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    if (!_speechEnabled) {
      print(
          'Speech recognition not enabled or permission denied. Check microphone permissions.');
      return;
    }

    setState(() => _isListening = true);
    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          setState(() {
            _voiceText = result.recognizedWords;
            _controller.text = _voiceText;
          });
          print("Recognized words: ${_controller.text}");
        },
        listenFor: const Duration(seconds: 30), // Extend listen duration
        pauseFor: const Duration(seconds: 3),
        onSoundLevelChange: (level) => print("sound level $level"),
        cancelOnError: true,
      );
    } catch (e) {
      print("Error during speech recognition: $e");
      setState(
          () => _isListening = false); // Ensure button reflects stopped state
    }
  }

  void _stopListening() {
    setState(() => _isListening = false);
    _speechToText.stop();
    if (_controller.text.isNotEmpty) {
      _sendMessage();
    }
  }

  final List<Map<String, String>> personas = [
    {
      'image': 'assets/images/bible.png',
      'label': 'Bible',
      'prompt':
          'Answer as a biblical scholar in 4-5 small sentences in simple english for 4-8 years old, keep it light hearted with emojis'
    },
    {
      'image': 'assets/images/history.png',
      'label': 'History',
      'prompt':
          'Respond from a historical perspective in 4-5 small sentences in simple english for 4-8 years old, keep it light hearted with emojis'
    },
    {
      'image': 'assets/images/science.png',
      'label': 'Science',
      'prompt':
          'Provide scientifically accurate answers in 4-5 small sentences in simple english for 4-8 years old, keep it light hearted with emojis'
    },
    {
      'image': 'assets/images/language.png',
      'label': 'Language',
      'prompt':
          'Focus on linguistic analysis in 4-5 small sentences in simple english for 4-8 years old, keep it light hearted with emojis'
    },
  ];

  void _sendMessage() {
    final userInput = _controller.text;
    print(userInput);
    if (userInput.isNotEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          user: true,
          createdAt: DateTime.now(),
          text: userInput,
        ));
      });

      final gemini = Gemini.instance;
      final prompt = _selectedIndex != -1
          ? '${personas[_selectedIndex]['prompt']!} $userInput'
          : userInput;
      final responseStream = gemini.streamGenerateContent(prompt);

      responseStream.listen((event) {
        setState(() {
          print(event.output);
          if (_messages.isNotEmpty && !_messages.last.user) {
            // Append to the last message (if it's not a user message)
            _messages.last = ChatMessage(
              user: false,
              createdAt:
                  _messages.last.createdAt, // Keep the original timestamp
              text: _messages.last.text +
                  (event.output ?? ''), // Append the new text
            );
          } else {
            // Add a new message if the list is empty or the last message is a user message
            _messages.add(ChatMessage(
              user: false,
              createdAt: DateTime.now(),
              text: event.output ?? '',
            ));
          }
        });
        _scrollToBottom();
      }, onError: (error) {
        print("Error in streaming response: $error");
      });
      _controller.clear();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _speechToText.stop();
    _isTextToSpeechEnabled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 30),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: personas.length,
              itemBuilder: (context, index) {
                final persona = personas[index];
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: _selectedIndex == index
                              ? Border.all(color: Colors.blue, width: 2)
                              : null,
                        ),
                        child: CircleAvatar(
                          backgroundImage: AssetImage(persona['image']!),
                          radius: 30,
                        ),
                        margin: const EdgeInsets.all(16),
                      ),
                      const SizedBox(height: 0),
                      Text(
                        persona['label']!,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(
              height: 8), // Reduced space between persona list and message list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final ChatMessage message = _messages[index];
                final isUserMessage = message.user;

                return Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                  decoration: BoxDecoration(
                    color: isUserMessage
                        ? const Color.fromARGB(255, 216, 239, 255)
                        : Colors.white,
                  ),
                  child: ListTile(
                    title: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0.0),
                      child: Text(
                        message.text,
                        style:
                            const TextStyle(fontSize: 14, letterSpacing: -0.6),
                      ),
                    ),
                    trailing: !isUserMessage
                        ? IconButton(
                            icon: Icon(
                              isTextToSpeechEnabled
                                  ? Icons.volume_up
                                  : Icons.volume_off,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              setState(() {
                                isTextToSpeechEnabled = !isTextToSpeechEnabled;
                                print(
                                    'Speaker toggle pressed for message: ${message.text}, enabled: $isTextToSpeechEnabled');
                                // TODO: Implement Text-to-Speech Functionality here
                              });
                            },
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 26.0),
            child: Row(
              // Wrap with Row
              children: [
                Expanded(
                  // Wrap with Expanded
                  child: Listener(
                    onPointerDown: (details) {
                      _startListening();
                    },
                    onPointerUp: (details) {
                      _stopListening();
                    },
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isListening ? Colors.red : Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: Text(
                        _isListening ? 'Release to Send' : 'Press and Ask',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class ChatMessage {
  final bool user;
  final DateTime createdAt;
  final String text;

  ChatMessage({
    required this.user,
    required this.createdAt,
    required this.text,
  });
}
