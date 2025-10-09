import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_setup_page.dart';
import 'login_page.dart';
import 'nearby_players_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        title: const Text(
          'PlayersConnect',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('players')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Center(child: Text('No profile found'));
          }

          final username = data['username'] ?? 'Gamer';
          final platforms =
              (data['platforms'] as List<dynamic>?)?.join(', ') ?? 'Unknown';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: InteractiveViewer(
                                clipBehavior: Clip.none,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const CircleAvatar(
                                    radius: 120,
                                    backgroundColor: Colors.deepPurple,
                                    child: Icon(Icons.person,
                                        color: Colors.white, size: 120),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Hero(
                        tag: 'profile_avatar',
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.deepPurple,
                          child:
                          Icon(Icons.person, color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi, $username 👋',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Platforms: $platforms',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),

                    // Popup Menu (⋮)
                    PopupMenuButton<String>(
                      icon:
                      const Icon(Icons.more_vert, color: Colors.deepPurple),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileSetupPage(isEditing: true),
                            ),
                          );
                        } else if (value == 'logout') {
                          await FirebaseAuth.instance.signOut();

                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                                  (route) => false,
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.deepPurple),
                              SizedBox(width: 10),
                              Text('Edit Profile'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: Colors.redAccent),
                              SizedBox(width: 10),
                              Text('Logout'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Quick Actions Section
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 10),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _featureCard(Icons.people, 'Nearby Players', context),
                    _featureCard(
                        Icons.videogame_asset, 'Borrow Games', context),
                    _featureCard(Icons.chat, 'Chat Rooms', context),
                    _featureCard(Icons.leaderboard, 'Leaderboard', context),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper for feature cards
  Widget _featureCard(IconData icon, String title, BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title feature coming soon!')),
        );
      },
      child: Card(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.deepPurple, size: 40),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
