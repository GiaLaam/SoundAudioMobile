import 'package:flutter/material.dart';
import 'dart:async';
import '../services/audio_player_service.dart';
import '../services/music_api_service.dart';
import '../services/signalr_service.dart';
import '../theme.dart';
import '../screens/player_screen.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/playlist_screen.dart';
import '../screens/profile_screen.dart';

/// Widget gốc với bottom nav và miniplayer cố định
class AppScaffold extends StatefulWidget {
  const AppScaffold({Key? key}) : super(key: key);

  // GlobalKey để truy cập state từ bên ngoài
  static final GlobalKey<AppScaffoldState> scaffoldKey = GlobalKey<AppScaffoldState>();

  @override
  State<AppScaffold> createState() => AppScaffoldState();
}

class AppScaffoldState extends State<AppScaffold> {
  int _currentIndex = 0;
  final AudioPlayerService _audioService = AudioPlayerService();
  final SignalRService _signalRService = SignalRService();
  
  StreamSubscription<Map<String, dynamic>>? _playbackInfoSubscription;
  StreamSubscription<String>? _stopPlaybackSubscription;
  
  // GlobalKey cho mỗi Navigator để duy trì state
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    PlaylistScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupSignalRListeners();
  }

  @override
  void dispose() {
    _playbackInfoSubscription?.cancel();
    _stopPlaybackSubscription?.cancel();
    super.dispose();
  }

  void _setupSignalRListeners() {
    // Lắng nghe khi thiết bị khác bắt đầu phát nhạc
    _playbackInfoSubscription = _signalRService.playbackInfoStream.listen((data) {
      final songInfo = data['songInfo'] as Map<String, dynamic>?;
      if (songInfo != null && mounted) {
        _showPlaybackTransferDialog(songInfo);
      }
    });

    // Lắng nghe lệnh dừng phát từ thiết bị khác
    _stopPlaybackSubscription = _signalRService.stopPlaybackStream.listen((deviceId) {
      if (mounted) {
        // Dừng phát nhạc trên thiết bị này
        _audioService.pause();
      }
    });
  }

  void _showPlaybackTransferDialog(Map<String, dynamic> songInfo) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon thông báo
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Tiêu đề
                const Text(
                  'Phiên nghe nhạc đã chuyển',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Thông tin
                Text(
                  'Đang phát trên thiết bị khác',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Tên bài hát nếu có
                if (songInfo['songName'] != null)
                  Text(
                    songInfo['songName'],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                
                const SizedBox(height: 20),
                
                // Nút đóng
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Đã hiểu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method để chuyển tab từ bên ngoài
  void switchToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  // Method tiện lợi để chuyển về trang chủ
  void switchToHomeTab() {
    switchToTab(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: Column(
        children: [
          // Nội dung chính với nested navigation
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: List.generate(
                _screens.length,
                (index) => Navigator(
                  key: _navigatorKeys[index],
                  onGenerateRoute: (settings) {
                    return MaterialPageRoute(
                      builder: (context) => _screens[index],
                    );
                  },
                ),
              ),
            ),
          ),

          // Mini Player - luôn cố định
          StreamBuilder<Song?>(
            stream: _audioService.currentSongStream,
            builder: (context, songSnap) {
              final song = songSnap.data;
              if (song == null) return const SizedBox.shrink();

              return StreamBuilder<bool>(
                stream: _audioService.isPlayingStream,
                builder: (context, playSnap) {
                  final isPlaying = playSnap.data ?? false;

                  return GestureDetector(
                    onTap: () {
                      // Navigate to player screen từ root navigator
                      Navigator.of(context, rootNavigator: true).push(
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
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause_circle : Icons.play_circle,
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
                  );
                },
              );
            },
          ),
        ],
      ),

      // Bottom Navigation Bar - luôn cố định
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: SpotifyTheme.background,
        selectedItemColor: SpotifyTheme.primary,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_filled), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Tìm kiếm'),
          BottomNavigationBarItem(
              icon: Icon(Icons.library_music), label: 'Thư viện'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    );
  }
}
