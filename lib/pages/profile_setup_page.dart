import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'login_page.dart';

class ProfileSetupPage extends StatefulWidget {
  final bool isEditing; // 👈 flag to know mode

  const ProfileSetupPage({super.key, this.isEditing = false});

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

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final doc =
      await FirebaseFirestore.instance.collection('players').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          _usernameController.text = data['username'] ?? '';
          final platforms = data['platforms'];
          _selectedPlatforms
            ..clear()
            ..addAll(platforms != null ? List<String>.from(platforms) : []);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_usernameController.text.trim().isEmpty || _selectedPlatforms.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    await FirebaseFirestore.instance.collection('players').doc(user.uid).set({
      'email': user.email,
      'username': _usernameController.text.trim(),
      'platforms': _selectedPlatforms,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ✅ Different behavior depending on mode
    if (widget.isEditing) {
      // Editing existing profile → stay logged in, go back to Home
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
        );
      }
    } else {
      // First-time setup → sign out, go to login
      await FirebaseAuth.instance.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile setup complete! Please log in.')),
      );
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Profile' : 'Set up your Profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select your platforms',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _availablePlatforms.map((platform) {
                final isSelected = _selectedPlatforms.contains(platform);
                return FilterChip(
                  label: Text(platform),
                  selected: isSelected,
                  selectedColor: Colors.deepPurple,
                  labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPlatforms.add(platform);
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
                child: Text(
                  widget.isEditing ? 'Save Changes' : 'Save Profile',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
