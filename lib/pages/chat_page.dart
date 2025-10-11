// lib/pages/chat_page.dart
import 'dart:async';
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
  StreamSubscription<QuerySnapshot>? _messagesSub;

  @override
  void initState() {
    super.initState();
    _setupChat();
    _startMessageListener();
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupChat() {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final ids = [myUid, widget.otherUid]..sort();
    _chatId = ids.join('_');
  }

  void _startMessageListener() {
    final firestore = FirebaseFirestore.instance;
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    // Listen to messages; we'll update unread messages when snapshot arrives.
    _messagesSub = firestore
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .listen((snap) async {
      try {
        // Only check the most recent N messages to avoid scanning a huge history.
        const int limitToCheck = 50;
        final docs = snap.docs;
        final startIndex = docs.length > limitToCheck ? docs.length - limitToCheck : 0;

        final WriteBatch batch = firestore.batch();
        var needsCommit = false;

        for (int i = startIndex; i < docs.length; i++) {
          final doc = docs[i];
          final data = doc.data() as Map<String, dynamic>;
          final senderId = (data['senderId'] as String?) ?? '';
          final readByList = (data['readBy'] as List?)?.cast<String>() ?? <String>[];

          // If this message is from other user and current user hasn't read it yet:
          if (senderId != myUid && !readByList.contains(myUid)) {
            batch.update(doc.reference, {
              'readBy': FieldValue.arrayUnion([myUid]),
            });
            needsCommit = true;
          }
        }

        if (needsCommit) {
          await batch.commit();
          // Optionally, you can also update chat doc's lastTimestamp to trigger other listeners,
          // but not required because message doc updates already trigger the chat rooms stream.
        }
      } catch (e, st) {
        debugPrint('Error marking messages read: $e\n$st');
      }
    }, onError: (e) {
      debugPrint('Message listener error: $e');
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final myUid = FirebaseAuth.instance.currentUser!.uid;
    _msgController.clear();

    final firestore = FirebaseFirestore.instance;
    final chatRef = firestore.collection('chats').doc(_chatId);

    // Ensure a top-level chat doc exists and has lastMessage + participants
    await chatRef.set({
      'participants': [myUid, widget.otherUid],
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Add the message with readBy containing sender
    await chatRef.collection('messages').add({
      'senderId': myUid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [myUid],
    });

    // scroll to bottom shortly after
    await Future.delayed(const Duration(milliseconds: 200));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
                    final isMe = (msg['senderId'] as String?) == myUid;
                    final text = msg['text'] ?? '';
                    final ts = (msg['timestamp'] as Timestamp?)?.toDate();
                    final timeStr = ts == null
                        ? ''
                        : "${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}";

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.deepPurple.shade400 : Colors.grey.shade300,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                            bottomRight: !isMe ? const Radius.circular(16) : Radius.zero,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              text,
                              style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              timeStr,
                              style: TextStyle(
                                  color: isMe ? Colors.white70 : Colors.black54, fontSize: 11),
                            ),
                          ],
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
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