import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class ChatRoomsPage extends StatelessWidget {
  const ChatRoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Rooms'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: myUid)
            .orderBy('lastTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No recent chats yet.'));
          }

          final chatDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chatDocs.length,
            itemBuilder: (context, i) {
              final chatData = chatDocs[i].data() as Map<String, dynamic>;
              final chatId = chatDocs[i].id;
              final lastMsg = chatData['lastMessage'] ?? '';
              final timestamp =
              (chatData['lastTimestamp'] as Timestamp?)?.toDate();
              final participants =
              List<String>.from(chatData['participants'] ?? []);
              final otherUid =
              participants.firstWhere((id) => id != myUid, orElse: () => '');

              if (otherUid.isEmpty) return const SizedBox();

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, msgSnap) {
                  if (!msgSnap.hasData || msgSnap.data!.docs.isEmpty) {
                    return const SizedBox();
                  }

                  final msg =
                  msgSnap.data!.docs.first.data() as Map<String, dynamic>;
                  final readByList = (msg['readBy'] as List?) ?? [];
                  final isUnread = !readByList.contains(myUid);

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('players')
                        .doc(otherUid)
                        .get(),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData) {
                        return const ListTile(title: Text('Loading user...'));
                      }

                      final username = userSnap.data!.data() != null
                          ? (userSnap.data!.get('username') ?? 'Unknown Player')
                          : 'Unknown Player';

                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.deepPurple,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(username),
                        subtitle: Text(
                          lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatTime(timestamp),
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12),
                            ),
                            if (isUnread)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: CircleAvatar(
                                  radius: 5,
                                  backgroundColor: Colors.blue,
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                otherUid: otherUid,
                                otherUsername: username,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static String _formatTime(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    if (now.difference(t).inDays == 0) {
      return "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
    } else {
      return "${t.day}/${t.month}";
    }
  }
}
