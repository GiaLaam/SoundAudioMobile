import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/bottom_nav_screen.dart';
import 'services/audio_player_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService().loadUserFromPrefs();
  await AudioPlayerService().init();
  runApp(const SpotifyApp());
}

class SpotifyApp extends StatelessWidget {
  const SpotifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotify Clone',
      debugShowCheckedModeBanner: false,
      theme: SpotifyTheme.darkTheme,
      home: const BottomNavScreen(),
    );
  }
}
