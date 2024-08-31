import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:dart_openai/dart_openai.dart';

void main() async {
  runApp(const MyApp());
  OpenAI.apiKey = '';

  await Gemini.init(
      apiKey:
          'AIzaSyB9sU_QRwE8hYt1lkh6vK0xBkJ5M6Tgbx8'); // Replace with your actual API key
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

        // Add the response to the messages list
        setState(() {
          _messages.add(ChatMessage(
            user: false,
            createdAt: DateTime.now(),
            text: results,
          ));
        });

        // Scroll to the bottom of the list
        _scrollToBottom();
      }).catchError((e) {
        print(e);
      });
    }
  }

// Future<String> getOpenAIResponse(String userInput) async {
//   final chatCompletion = await OpenAI.instance.chat.create(
//     model: "gpt-3.5-turbo", // You can also use "gpt-4" if you have access
//     messages: [
//       OpenAIChatCompletionChoiceMessageModel(
//         content: userInput,
//         role: OpenAIChatMessageRole.user,
//       ),
//     ],
//   );

//   return chatCompletion.choices.first.message.content;
// }

  void _scrollToBottom() {
    // Ensure the list view is scrolled to the bottom
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       backgroundColor: Theme.of(context).colorScheme.inversePrimary,
  //       title: Text(widget.title),
  //     ),
  //     body: Column(
  //       children: [
  //         Expanded(
  //           child: ListView.builder(
  //             itemCount: _messages.length,
  //             itemBuilder: (context, index) {
  //               return ListTile(
  //                 title: Text(_messages[index]),
  //               );
  //             },
  //           ),
  //         ),
  //         Padding(
  //           padding: const EdgeInsets.all(8.0),
  //           child: Row(
  //             children: [
  //               Expanded(
  //                 child: TextField(
  //                   controller: _controller,
  //                   decoration: InputDecoration(
  //                     hintText: 'Type your message...',
  //                     border: OutlineInputBorder(
  //                       borderRadius: BorderRadius.circular(30.0),
  //                     ),
  //                     contentPadding: const EdgeInsets.symmetric(
  //                       vertical: 10.0,
  //                       horizontal: 20.0,
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //               IconButton(
  //                 icon: const Icon(Icons.send),
  //                 onPressed: _sendMessage,
  //                 iconSize: 30,
  //                 color: Colors.blue,
  //                 padding: const EdgeInsets.all(8.0),
  //                 constraints: BoxConstraints(),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
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
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isUserMessage ? Colors.grey.shade300 : Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade800, width: 2),
                      bottom: BorderSide(color: Colors.grey.shade800, width: 2),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: isUserMessage
                        ? Icon(Icons.question_answer, color: Colors.blue)
                        : null,
                    title: Text(
                      message.text,
                      textAlign:
                          isUserMessage ? TextAlign.left : TextAlign.right,
                    ),
                    trailing: isUserMessage
                        ? null
                        : Icon(Icons.send, color: Colors.green),
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
