import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import flutter_dotenv

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is initialized
  await dotenv.load(fileName: ".env"); // Load the .env file

  await Gemini.init(apiKey: dotenv.env['GEMINI_API_KEY']!);

  runApp(const MyApp());
  // OpenAI.apiKey = '';
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

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

  final List<Map<String, String>> personas = [
    {
      'image': 'assets/images/bible.png',
      'label': 'Bible',
      'prompt':
          'Answer as a biblical scholar in 4-5 small sentences in simple english for 4-8 years old'
    },
    {
      'image': 'assets/images/history.png',
      'label': 'History',
      'prompt':
          'Respond from a historical perspective in 4-5 small sentences in simple english for 4-8 years old'
    },
    {
      'image': 'assets/images/science.png',
      'label': 'Science',
      'prompt':
          'Provide scientifically accurate answers in 4-5 small sentences in simple english for 4-8 years old'
    },
    {
      'image': 'assets/images/language.png',
      'label': 'Language',
      'prompt':
          'Focus on linguistic analysis in 4-5 small sentences in simple english for 4-8 years old'
    },
  ];

  void _sendMessage() {
    final userInput = _controller.text;

    if (userInput.isNotEmpty) {
      // Add user question to the messages list
      setState(() {
        _messages.add(ChatMessage(
          user: true,
          createdAt: DateTime.now(),
          text: userInput,
        ));
      });

      // Call Gemini API with persona context
      final gemini = Gemini.instance;
      final prompt = _selectedIndex != -1
          ? '${personas[_selectedIndex]['prompt']!} $userInput'
          : userInput;

      // Start streaming response from Gemini API
      final responseStream = gemini.streamGenerateContent(prompt);

      responseStream.listen((event) {
        // Handle each word as it comes in
        setState(() {
          _messages.add(ChatMessage(
            user: false,
            createdAt: DateTime.now(),
            text: event.output ?? '', // Add each part of the output
          ));
        });
        _scrollToBottom(); // Scroll to the bottom after updating messages
      }, onError: (error) {
        print("Error in streaming response: $error");
      });

      _controller.clear(); // Clear the text field after sending
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Adding SizedBox for extra space
          const SizedBox(height: 10),
          SizedBox(
            height: 116, // Increased height to accommodate labels
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
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type your question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10.0,
                        horizontal: 20.0,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  iconSize: 30,
                  color: Colors.blue,
                  padding: const EdgeInsets.all(8.0),
                  constraints: const BoxConstraints(),
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
