import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final String otherUid;
  final String otherUsername;

  const ChatPage({super.key, required this.otherUid, required this.otherUsername});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  late String _chatId;

  @override
  void initState() {
    super.initState();
    _setupChat();
  }

  void _setupChat() {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final ids = [myUid, widget.otherUid]..sort();
    _chatId = ids.join('_'); // unique chat room ID
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final myEmail = FirebaseAuth.instance.currentUser!.email ?? 'Unknown';

    _msgController.clear();

    final firestore = FirebaseFirestore.instance;
    final chatRef = firestore.collection('chats').doc(_chatId);

    // ✅ Create or update chat doc with summary info
    await chatRef.set({
      'participants': [myUid, widget.otherUid],
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ✅ Add actual message
    await chatRef.collection('messages').add({
      'senderId': myUid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await Future.delayed(const Duration(milliseconds: 200));
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUsername),
        backgroundColor: Colors.deepPurple,
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == myUid;
                    return Align(
                      alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 10),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.deepPurple.shade400
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft:
                            isMe ? const Radius.circular(16) : Radius.zero,
                            bottomRight:
                            !isMe ? const Radius.circular(16) : Radius.zero,
                          ),
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 16),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.deepPurple,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
