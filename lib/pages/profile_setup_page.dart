import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import '../pages/login_page.dart';

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
      final doc = await FirebaseFirestore.instance
          .collection('players')
          .doc(user.uid)
          .get();

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
      // optional: show error
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
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Sign out after successful profile setup
    await FirebaseAuth.instance.signOut();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile setup complete! Please log in.')),
    );

    // Navigate to Login Page
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
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
                style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      color:
                      isSelected ? Colors.white : Colors.black),
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
                child: const Text(
                  'Save Profile',
                  style:
                  TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}