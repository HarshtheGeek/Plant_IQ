import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

class ChatBot extends StatefulWidget {
  const ChatBot({super.key});

  @override
  State<ChatBot> createState() => _ChatBotState();
}

class _ChatBotState extends State<ChatBot> {
  final Gemini gemini = Gemini.instance;
  List<ChatMessage> messages = [];
  ChatUser currentUser = ChatUser(id: "0", firstName: "Farmer");
  ChatUser geminiUser = ChatUser(
      id: "1",
      firstName: "AgriAssist",
      profileImage: "assets/farmer_bot.png"
  );


  final Color primaryGreen = const Color(0xFF3A8A40);
  final Color lightGreen = const Color(0xFFEDF7EE);
  final Color backgroundGreen = const Color(0xFFF5F9F5);
  final Color accentGreen = const Color(0xFF4CAF50);
  final Color darkGreen = const Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "AgriAssist",
          style: TextStyle(
            fontFamily: 'PoppinsMed',
            fontWeight: FontWeight.bold,
            fontSize: 26,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryGreen,
        elevation: 2,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/farmer_bot.png',
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: _buildUI(),
      backgroundColor: backgroundGreen,
    );
  }

  Widget _buildUI() {
    return DashChat(
      currentUser: currentUser,
      onSend: _sendMessage,
      messages: messages,
      messageOptions: MessageOptions(
        currentUserContainerColor: accentGreen,
        containerColor: lightGreen,
        currentUserTextColor: Colors.white,
        textColor: darkGreen,
        showTime: false,
        messagePadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        avatarBuilder: (user, _, __) {
          if (user.id == geminiUser.id) {
            return CircleAvatar(
              backgroundImage: const AssetImage('assets/farmer_bot.png'),
              backgroundColor: lightGreen,
              radius: 18,
            );
          }
          return CircleAvatar(
            backgroundImage: const AssetImage('assets/farmer.png'),
            backgroundColor: accentGreen.withOpacity(0.1),
            radius: 18,
          );
        },
      ),
      inputOptions: InputOptions(
        inputDecoration: InputDecoration(
          hintText: "Ask about farming, crops, or agriculture...",
          hintStyle: TextStyle(
            color: darkGreen.withOpacity(0.6),
            fontFamily: 'PoppinsMed',
            fontSize: 14,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24.0),
            borderSide: BorderSide(color: accentGreen.withOpacity(0.3), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24.0),
            borderSide: BorderSide(color: accentGreen.withOpacity(0.3), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24.0),
            borderSide: BorderSide(color: accentGreen, width: 1.5),
          ),
          prefixIcon: Icon(Icons.agriculture_outlined, color: darkGreen.withOpacity(0.7)),
        ),
        inputToolbarPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        inputToolbarMargin: const EdgeInsets.all(5),
        inputToolbarStyle: BoxDecoration(
          color: backgroundGreen,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        inputMaxLines: 5,
        sendButtonBuilder: (onSend) {
          return Container(
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: primaryGreen,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: onSend,
            ),
          );
        },
      ),
      scrollToBottomOptions: ScrollToBottomOptions(
        scrollToBottomBuilder: (scrollController) => FloatingActionButton(
          mini: true,
          backgroundColor: Color(0xFF3A8A40),
          child: Icon(Icons.arrow_downward, color: Colors.white, size: 20),
          onPressed: () {},
        ),
      ),
    );
  }

  void _sendMessage(ChatMessage chatMessage) {
    setState(() {
      messages = [chatMessage, ...messages];
    });

    try {
      String question = chatMessage.text;
      gemini.streamGenerateContent(question).listen((event) {
        String response = event.content?.parts?.fold("", (previous, current) => "$previous ${current.text}") ?? "";

        if (messages.isNotEmpty && messages.first.user == geminiUser) {
          ChatMessage lastMessage = messages.removeAt(0);
          lastMessage.text += response;
          setState(() {
            messages = [lastMessage, ...messages];
          });
        } else {
          ChatMessage message = ChatMessage(user: geminiUser, createdAt: DateTime.now(), text: response);
          setState(() {
            messages = [message, ...messages];
          });
        }
      });
    } catch (e) {
      print(e);
    }
  }
}