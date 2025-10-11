import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
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
  bool _locLoading = false;
  Position? _currentPosition;

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

          final loc = data['location'];
          if (loc != null) {
            _currentPosition = Position(
              latitude: loc['lat'],
              longitude: loc['lng'],
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0, // ✅ Added
              headingAccuracy: 0, // ✅ Added
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 📍 Sync or refresh current location
  Future<void> _syncLocation() async {
    setState(() => _locLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      // ✅ Updated Geolocator API usage
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() => _currentPosition = pos);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('players').doc(user.uid).set({
          'location': {'lat': pos.latitude, 'lng': pos.longitude},
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location synced successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    } finally {
      if (mounted) setState(() => _locLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_usernameController.text.trim().isEmpty || _selectedPlatforms.isEmpty) {
      if (!mounted) return;
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

    if (!mounted) return;

    // ✅ Different behavior depending on mode
    if (widget.isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
      );
    } else {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile setup complete! Please log in.')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
      );
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
        child: SingleChildScrollView(
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

              // 📍 Location Button Section (Updated Row Layout)
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _locLoading ? null : _syncLocation,
                      icon: const Icon(Icons.my_location, color: Colors.white),
                      label: Text(
                        _currentPosition == null
                            ? 'Sync Location'
                            : 'Refresh Location',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              if (_currentPosition != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Current Location: '
                      '${_currentPosition!.latitude.toStringAsFixed(4)}, '
                      '${_currentPosition!.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],

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
                    style:
                    const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
