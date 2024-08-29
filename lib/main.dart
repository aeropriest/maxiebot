import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() async {
  // await dotenv.load(); // Load the .env file

  Gemini.init(apiKey: '');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Maxie Bot'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController controller = TextEditingController();

  String results = "Show results here...";

  // late gai.GenerativeModel model;
  late ImagePicker imagePicker;
  @override
  initState() {
    super.initState();
    imagePicker = ImagePicker();
  }
  // generate() {
  //   super.initState();
  //   //   model = gai.GenerativeModel(
  //   //       model: "gemini-pro", apiKey: dotenv.env['GOOGLE_API_KEY']);
  // }

  bool imageSelected = false;
  late File selectedImage;

  pickImage() async {
    final XFile? image =
        await imagePicker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      imageSelected = true;
      selectedImage = File(image.path);
      ChatMessage message =
          ChatMessage(user: user, createdAt: DateTime.now(), text: '', medias: [
        ChatMedia(url: image.path, fileName: image.name, type: MediaType.image)
      ]);
      messages.insert(0, message);
      setState(() {
        messages;
      });
    }
  }

  processInput() async {
    String userInput = controller.text;
    ChatMessage message =
        ChatMessage(user: user, createdAt: DateTime.now(), text: userInput);
    messages.insert(0, message);
    setState(() {
      messages;
    });
    // final content = [gai.Content.text(controller.text)];
    // final response = await model.generateContent(content);
    // results = response.text!;
    // setState(() {
    //   results;
    // });

    final gemini = Gemini.instance;
    if (imageSelected) {
      gemini.textAndImage(
          text: userInput,
          images: [selectedImage.readAsBytesSync()]).then((value) {
        results = value!.output!;
        controller.clear();
        ChatMessage message = ChatMessage(
            user: geminiUser, createdAt: DateTime.now(), text: results);
        messages.insert(0, message);
        setState(() {
          messages;
        });
      }).then((value) {
        // log(value?.content?.parts?.last.text ?? '');
        // ChatMessage message = ChatMessage(
        //     user: geminiUser,
        //     createdAt: DateTime.now(),
        //     text: value?.content?.parts?.last.text);
        // messages.insert(0, value?.content?.parts?.last.text);
        // setState(() {
        //   messages;
        // });
      }).catchError((e) => log(e));
      imageSelected = false;
    } else {
      gemini.text(userInput).then((value) {
        results = value!.output!;
        controller.clear();
        ChatMessage message = ChatMessage(
            user: geminiUser, createdAt: DateTime.now(), text: results);
        messages.insert(0, message);
        setState(() {
          messages;
        });
      }).catchError((e) => print(e));
    }
  }

  // void handleDone() {
  //   if (isTTS) {
  //     flutterTts.speak(results);
  //   }
  //   setState(() {
  //     isLoading = false;
  //   });
  // }

  ChatUser user = ChatUser(
    id: '1',
    firstName: 'Hamza',
    lastName: 'Asif',
  );

  ChatUser geminiUser = ChatUser(
    id: '2',
    firstName: 'Gemini',
    lastName: 'AI',
  );

  List<ChatMessage> messages = <ChatMessage>[];

  bool isTTS = false;
  bool isDark = false;
  bool isLoading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        leading: InkWell(
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Icon(
              isDark ? Icons.sunny : Icons.nightlight_round_rounded,
              color: Colors.white,
            ),
          ),
          onTap: () {
            setState(() {
              if (isDark) {
                isDark = false;
              } else {
                isDark = true;
              }
            });
          },
        ),
        actions: [
          InkWell(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                isTTS ? Icons.surround_sound : Icons.surround_sound_outlined,
                color: Colors.white,
              ),
            ),
            onTap: () {
              setState(() {
                if (isTTS) {
                  isTTS = false;
                } else {
                  isTTS = true;
                }
              });
            },
          )
        ],
      ),
      body: Center(
        child: Stack(
          children: [
            Container(
              // decoration: BoxDecoration(
              //     image: DecorationImage(
              //         image: const AssetImage("assets/bg.jpg"),
              //         fit: BoxFit.cover,
              //         invertColors: isDark)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Expanded(
                    child: DashChat(
                      currentUser: user,
                      onSend: (ChatMessage m) {},
                      messages: messages,
                      readOnly: true,
                    ),
                  ),
                  //Text(results),
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Row(
                      children: [
                        Expanded(
                            child: Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0, right: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: "Type here..."),
                                  ),
                                ),
                                InkWell(
                                  child: const Icon(Icons.image),
                                  onTap: () {
                                    pickImage();
                                  },
                                )
                              ],
                            ),
                          ),
                        )),
                        ElevatedButton(
                          onPressed: () {
                            // _startListening();
                          },
                          style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              backgroundColor: Colors.green.shade400,
                              padding: const EdgeInsets.all(10)),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            processInput();
                          },
                          style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              backgroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.all(10)),
                          child: const Icon(
                            Icons.send,
                            color: Colors.white,
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            Center(
              child: isLoading ? Lottie.asset('assets/ai.json') : Container(),
            )
          ],
        ),
      ),
    );
  }
}
