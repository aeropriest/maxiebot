import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
  int _selectedIndex = -1;

  final List<Map<String, String>> personas = [
    {
      'image': 'assets/images/bible.png',
      'label': 'Bible',
      'prompt': 'Answer as a biblical scholar'
    },
    {
      'image': 'assets/images/history.png',
      'label': 'History',
      'prompt': 'Respond from a historical perspective'
    },
    {
      'image': 'assets/images/science.png',
      'label': 'Science',
      'prompt': 'Provide scientifically accurate answers'
    },
    {
      'image': 'assets/images/language.png',
      'label': 'Language',
      'prompt': 'Focus on linguistic analysis'
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

      gemini.text(prompt).then((value) {
        final results = value?.output ?? 'No response';
        _controller.clear(); // Clear the text field after sending

        if (value != null && value.output != null) {
          print(value.output);
          _controller.clear();
          setState(() {
            _messages.add(ChatMessage(
              user: false,
              createdAt: DateTime.now(),
              text: results,
            ));
          });
          _scrollToBottom();
        }
      });
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
          SizedBox(
            height: 120, // Increased height to accommodate labels
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: personas.length,
              itemBuilder: (context, index) {
                final persona = personas[index];
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    width: 100, // Added width for better spacing
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: _selectedIndex == index
                          ? Border.all(color: Colors.blue, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center, // Center content vertically
                      children: [
                        CircleAvatar(
                          backgroundImage: AssetImage(persona['image']!),
                          radius: 30,
                        ),
                        const SizedBox(
                            height: 8), // Added spacing between image and text
                        Text(
                          persona['label']!,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
                    leading: isUserMessage
                        ? const Icon(Icons.question_answer, color: Colors.blue)
                        : const Icon(Icons.send, color: Colors.green),
                    title: Text(
                      message.text,
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
                        borderRadius: BorderRadius.circular(30.0),
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
