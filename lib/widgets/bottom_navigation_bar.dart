import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/playlist_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/player_screen.dart';
import '../services/audio_player_service.dart';
import '../theme.dart';
import '../services/music_api_service.dart';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int _currentIndex = 0;
  final AudioPlayerService _audioService = AudioPlayerService();

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    PlaylistScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: Stack(
        children: [
          _screens[_currentIndex],

          // 🎵 Mini Player — luôn hiển thị cố định
          StreamBuilder<Song?>(
            stream: _audioService.currentSongStream,
            builder: (context, songSnap) {
              final song = songSnap.data;
              if (song == null) return const SizedBox.shrink();

              return StreamBuilder<bool>(
                stream: _audioService.isPlayingStream,
                builder: (context, playSnap) {
                  final isPlaying = playSnap.data ?? false;

                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0, // 🔹 đúng bằng chiều cao bottom nav bar
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(
                              audioPlayer: _audioService.player,
                              currentSong: song,
                              isPlaying: isPlaying,
                              onTogglePlay: () {
                                if (isPlaying) {
                                  _audioService.pause();
                                } else {
                                  _audioService.play();
                                }
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 70,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E1E1E),
                          border: Border(
                            top: BorderSide(color: Colors.black, width: 0.5),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            // Ảnh nhạc
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                "https://willing-baltimore-brunette-william.trycloudflare.com${song.imageUrl}",
                                width: 55,
                                height: 55,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.music_note,
                                  color: Colors.white54,
                                  size: 40,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Thông tin bài hát
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.name ?? "Không rõ tên bài hát",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    song.fileName ?? "",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isPlaying
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                                color: Colors.greenAccent,
                                size: 40,
                              ),
                              onPressed: () {
                                if (isPlaying) {
                                  _audioService.pause();
                                } else {
                                  _audioService.play();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),

      // 🧭 Thanh điều hướng dưới cùng
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: SpotifyTheme.background,
        selectedItemColor: SpotifyTheme.primary,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Tìm kiếm'),
          BottomNavigationBarItem(
              icon: Icon(Icons.library_music), label: 'Thư viện'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    );
  }
}
