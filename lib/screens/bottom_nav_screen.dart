import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/playlist_screen.dart';
import '../screens/profile_screen.dart';
import '../widgets/scaffold_with_miniplayer.dart';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    PlaylistScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithMiniPlayer(
      currentIndex: _currentIndex,
      showBottomNav: true,
      onNavigationTap: (index) => setState(() => _currentIndex = index),
      child: _screens[_currentIndex],
    );
  }
}