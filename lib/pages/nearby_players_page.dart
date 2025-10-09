import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class NearbyPlayersPage extends StatefulWidget {
  const NearbyPlayersPage({super.key});

  @override
  State<NearbyPlayersPage> createState() => _NearbyPlayersPageState();
}

class _NearbyPlayersPageState extends State<NearbyPlayersPage> {
  double _selectedRadius = 10; // default radius in km
  List<Map<String, dynamic>> _nearbyPlayers = [];
  bool _loading = false;
  bool _hasSearched = false;
  Map<String, dynamic>? _myLocation; // current user's Firestore location

  @override
  void initState() {
    super.initState();
    _loadMyLocation();
  }

  Future<void> _loadMyLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
    await FirebaseFirestore.instance.collection('players').doc(uid).get();
    final data = doc.data();
    if (data != null && data['location'] != null) {
      setState(() => _myLocation = data['location']);
    }
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth's radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> _fetchNearbyPlayers() async {
    if (_myLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sync your location first.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _hasSearched = true;
    });

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = await FirebaseFirestore.instance.collection('players').get();

    final List<Map<String, dynamic>> nearby = [];

    for (final doc in snapshot.docs) {
      if (doc.id == myUid) continue;
      final data = doc.data();
      final loc = data['location'];
      if (loc == null) continue;

      final distance = _calculateDistance(
        _myLocation!['lat'],
        _myLocation!['lng'],
        loc['lat'],
        loc['lng'],
      );

      if (distance <= _selectedRadius) {
        nearby.add({
          'uid': doc.id,
          'username': data['username'] ?? 'Unknown',
          'platforms': (data['platforms'] as List?)?.join(', ') ?? 'N/A',
          'distance': distance.toStringAsFixed(2),
        });
      }
    }

    setState(() {
      _nearbyPlayers = nearby;
      _loading = false;
    });
  }

  void _openChat(Map<String, dynamic> player) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          otherUid: player['uid'],
          otherUsername: player['username'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Players'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Select Radius',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [5, 10, 20, 40].map((km) {
                return ChoiceChip(
                  label: Text('$km km'),
                  selected: _selectedRadius == km.toDouble(),
                  selectedColor: Colors.deepPurple,
                  labelStyle: TextStyle(
                    color: _selectedRadius == km.toDouble()
                        ? Colors.white
                        : Colors.black,
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedRadius = km.toDouble()),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _fetchNearbyPlayers,
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text(
                  'Find Players',
                  style: TextStyle(color: Colors.white), // visible
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : !_hasSearched
                  ? const SizedBox() // don’t show message before search
                  : _nearbyPlayers.isEmpty
                  ? const Center(child: Text('No players found near you.'))
                  : ListView.builder(
                itemCount: _nearbyPlayers.length,
                itemBuilder: (context, i) {
                  final p = _nearbyPlayers[i];
                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        child:
                        Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(p['username']),
                      subtitle: Text(
                        '${p['platforms']}\n${p['distance']} km away',
                      ),
                      isThreeLine: true,
                      trailing: ElevatedButton.icon(
                        onPressed: () => _openChat(p),
                        icon: const Icon(Icons.chat,
                            color: Colors.white, size: 18),
                        label: const Text('Chat',
                            style:
                            TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          minimumSize: const Size(70, 36),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
