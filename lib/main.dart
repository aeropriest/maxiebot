import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:dart_openai/dart_openai.dart';

void main() async {
  runApp(const MyApp());
  // OpenAI.apiKey = '';

  await Gemini.init(
      apiKey:
          'AIzaSyAAF2ge_4OszRJdJVT7fPpJtxMZuQ--o_Y'); // Replace with your actual API key
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gappu App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

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

      // Call Gemini API to get the answer
      final gemini = Gemini.instance;

      gemini.text(userInput).then((value) {
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

      // // Scroll to the bottom of the list

      // }).catchError((e) {
      //   print(e);
      // });
      // bool first = true;
      // print(userInput);
      // gemini
      //     .streamGenerateContent(userInput,
      //         generationConfig:
      //             GenerationConfig(temperature: 0.7, maxOutputTokens: 256))
      //     .listen((value) {
      //   print('Got the response...');
      // if (value != null && value.output != null) {
      //   print(value.output);
      //   _controller.clear();
      //   setState(() {
      //     _messages.add(ChatMessage(
      //       user: false,
      //       createdAt: DateTime.now(),
      //       text: value?.output ?? 'No response',
      //     ));
      //   });

      //     // Scroll to the bottom of the list
      //     _scrollToBottom();

      //     // Log the output results
      //     print('Output results: $value');
      //   } else {
      //     print('Received null or empty output from the response.');
      //   }
      // }).onError((e) => print(e));
    }
  }

  void _scrollToBottom() {
    // Ensure the list view is scrolled to the bottom
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
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
                        ? Icon(Icons.question_answer, color: Colors.blue)
                        : Icon(Icons.send, color: Colors.green),
                    title: Text(
                      message.text,
                      // textAlign:
                      //     isUserMessage ? TextAlign.right : TextAlign.left,
                    ),
                    // trailing: isUserMessage
                    //     ? null
                    //     : Icon(Icons.send, color: Colors.green),
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
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
