import 'package:flutter/material.dart';
// import 'package:flutter_chat_ui/flutter_chat_ui.dart';
// import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class NewChatScreen extends StatelessWidget {
  final List<dynamic> messages;
  final dynamic user;
  final void Function(dynamic) handleSendPressed;

  const NewChatScreen({
    Key? key,
    required this.messages,
    required this.user,
    required this.handleSendPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: const Center(child: Text('Chat UI temporarily disabled')),
    );
  }
}
