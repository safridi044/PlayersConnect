import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const PlayersConnect());
}

class PlayersConnect extends StatelessWidget {
  const PlayersConnect({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlayersConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// ================= AUTH GATE =================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _checkProfileExists(String uid) async {
    final doc =
    await FirebaseFirestore.instance.collection('players').doc(uid).get();
    return doc.exists;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          return FutureBuilder<bool>(
            future: _checkProfileExists(user.uid),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              if (profileSnapshot.data == true) {
                return const HomePage();
              } else {
                return const ProfileSetupPage();
              }
            },
          );
        }
        return const LoginPage();
      },
    );
  }
}

// ================= LOGIN PAGE =================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'PlayersConnect',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Login',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    ),
                    child: const Text('Create new account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= REGISTER PAGE =================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    try {
      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (userCred.user != null) {
        // After registration we go to profile setup (ProfileSetupPage will handle empty vs existing)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileSetupPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? 'Registration failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                'Register',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= PROFILE SETUP PAGE (prefills existing data) =================
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _usernameController = TextEditingController();
  final List<String> _selectedPlatforms = [];
  final List<String> _availablePlatforms = [
    'PlayStation',
    'Xbox',
    'PC',
    'Nintendo',
    'Mobile',
  ];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('players').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          _usernameController.text = (data['username'] ?? '') as String;
          final platforms = data['platforms'];
          _selectedPlatforms.clear();
          if (platforms != null && platforms is List) {
            for (final p in platforms) {
              if (p is String && !_selectedPlatforms.contains(p)) {
                _selectedPlatforms.add(p);
              }
            }
          }
        }
      }
    } catch (e) {
      // ignore quietly — will show empty form
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_selectedPlatforms.isEmpty || _usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('players').doc(user.uid).set({
      'email': user.email,
      'username': _usernameController.text.trim(),
      'platforms': _selectedPlatforms,
      'updatedAt': FieldValue.serverTimestamp(),
      // keep createdAt if exists by using merge
    }, SetOptions(merge: true));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select your platforms',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _availablePlatforms.map((platform) {
                final isSelected = _selectedPlatforms.contains(platform);
                return FilterChip(
                  label: Text(platform),
                  selected: isSelected,
                  selectedColor: Colors.deepPurple,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        if (!_selectedPlatforms.contains(platform)) {
                          _selectedPlatforms.add(platform);
                        }
                      } else {
                        _selectedPlatforms.remove(platform);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Your Gamer Tag',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Save Profile',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= HOME PAGE (CLEANER DESIGN, popup menu) =================
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
        // removed top-right logout button as requested
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
                // Compact profile header with popup menu
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // avatar tap -> edit profile
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileSetupPage(),
                          ),
                        );
                      },
                      child: const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.deepPurple,
                        child: Icon(Icons.person, color: Colors.white, size: 30),
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
                            style: const TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),

                    // Popup menu (⋮) — includes Edit and Logout
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.deepPurple),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileSetupPage(),
                            ),
                          );
                        } else if (value == 'logout') {
                          await FirebaseAuth.instance.signOut();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: const [
                              Icon(Icons.edit, color: Colors.deepPurple),
                              SizedBox(width: 10),
                              Text('Edit Profile'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: const [
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
                    _featureCard(Icons.videogame_asset, 'Borrow Games', context),
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
