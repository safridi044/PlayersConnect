import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'profile_setup_page.dart';
import 'login_page.dart';
import 'nearby_players_page.dart';
import 'chat_room_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Called when a message is received in the background
  debugPrint('📩 Background message: ${message.notification?.title}');
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _setupFirebaseMessaging();
  }

  // 🔔 Step 1: Setup Firebase Messaging end-to-end
  Future<void> _setupFirebaseMessaging() async {
    await _requestNotificationPermission();
    await _initializeLocalNotifications();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _setupForegroundListener();
    _saveAndMonitorFcmToken();
  }

  // 🔐 Step 2: Request notification permission
  Future<void> _requestNotificationPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Notification permission granted');
    } else {
      debugPrint('❌ Notification permission denied');
    }
  }

  // 🧩 Step 3: Initialize local notifications for Android
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidInit);

    await _localNotifications.initialize(initSettings);
  }

  // 📩 Step 4: Handle foreground notifications
  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
        );
      }
    });
  }

  // 💾 Step 5: Save FCM Token + Handle token refresh
  Future<void> _saveAndMonitorFcmToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Save token initially
    final token = await _messaging.getToken();
    await _saveTokenToFirestore(user.uid, token);

    // Listen for token refresh (in case it changes)
    _messaging.onTokenRefresh.listen((newToken) async {
      await _saveTokenToFirestore(user.uid, newToken);
      debugPrint('🔁 FCM Token refreshed and updated in Firestore');
    });
  }

  Future<void> _saveTokenToFirestore(String uid, String? token) async {
    if (token == null) return;
    await FirebaseFirestore.instance.collection('players').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
    debugPrint('📱 FCM Token saved to Firestore: $token');
  }

  // 🌟 UI Section
  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser!;
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
                // Profile Header
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
                                        color:
                                        Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const CircleAvatar(
                                    radius: 120,
                                    backgroundColor: Colors.deepPurple,
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 120,
                                    ),
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
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon:
                      const Icon(Icons.more_vert, color: Colors.deepPurple),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const ProfileSetupPage(isEditing: true),
                            ),
                          );
                        } else if (value == 'logout') {
                          await _auth.signOut();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
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

                // Quick Actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _featureCard(
                        Icons.people,
                        'Nearby Players',
                        context,
                            () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NearbyPlayersPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _featureCard(
                        Icons.chat,
                        'Chat Rooms',
                        context,
                            () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChatRoomsPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🔧 Helper widget
  Widget _featureCard(
      IconData icon,
      String title,
      BuildContext context,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
