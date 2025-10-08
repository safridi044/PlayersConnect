import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'utils/auth_gate.dart';

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
