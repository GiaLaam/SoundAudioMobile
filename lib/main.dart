import 'package:flutter/material.dart';
import 'theme.dart';
import 'services/audio_player_service.dart';
import 'services/auth_service.dart';
import 'services/signalr_service.dart';
import 'services/recently_played_service.dart';
import 'widgets/app_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService().loadUserFromPrefs();
  await AudioPlayerService().init();
  await RecentlyPlayedService().init();
  
  // Kết nối SignalR nếu user đã đăng nhập
  final user = AuthService().currentUser;
  if (user != null) {
    await SignalRService().connect();
  }
  
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
      home: AppScaffold(key: AppScaffold.scaffoldKey),
    );
  }
}
