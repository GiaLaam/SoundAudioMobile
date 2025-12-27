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

class AppScaffold extends StatefulWidget {
  const AppScaffold({Key? key}) : super(key: key);

  static final GlobalKey<AppScaffoldState> scaffoldKey = GlobalKey<AppScaffoldState>();

  @override
  State<AppScaffold> createState() => AppScaffoldState();
}

class AppScaffoldState extends State<AppScaffold> {
  int _currentIndex = 0;
  final AudioPlayerService _audioService = AudioPlayerService();
  final SignalRService _signalRService = SignalRService();

  StreamSubscription<Map<String, dynamic>>? _playbackInfoSubscription;
  StreamSubscription<Map<String, dynamic>>? _stopPlaybackSubscription;
  StreamSubscription<Map<String, dynamic>>? _deviceNotificationSubscription;
  
  // Tránh hiển thị snackbar trùng lặp
  DateTime? _lastSnackbarTime;
  static const _snackbarCooldown = Duration(seconds: 3);

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
    _deviceNotificationSubscription?.cancel();
    super.dispose();
  }

  void _setupSignalRListeners() {
    _playbackInfoSubscription = _signalRService.playbackInfoStream.listen((data) {
      final songInfo = data['songInfo'] as Map<String, dynamic>?;
      if (songInfo != null && mounted) {
        _showPlaybackTransferDialog(songInfo);
      }
    });

    // Lắng nghe thông báo từ AudioPlayerService khi bị dừng do thiết bị khác
    _deviceNotificationSubscription = _audioService.devicePlaybackNotificationStream.listen((data) {
      if (mounted) {
        final deviceName = data['deviceName'] ?? 'Another device';
        final songName = data['songName'] ?? '';
        _showDevicePlaybackSnackbar(deviceName, songName);
      }
    });
  }

  void _showDevicePlaybackSnackbar(String deviceName, String songName) {
    // Kiểm tra cooldown để tránh hiển thị quá nhiều
    final now = DateTime.now();
    if (_lastSnackbarTime != null && 
        now.difference(_lastSnackbarTime!) < _snackbarCooldown) {
      return;
    }
    _lastSnackbarTime = now;
    
    // Ẩn snackbar cũ nếu có
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SpotifyTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.speaker_group, color: SpotifyTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Đang phát trên $deviceName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (songName.isNotEmpty)
                      Text(
                        songName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: SpotifyTheme.surface,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        dismissDirection: DismissDirection.down,
      ),
    );
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
              color: SpotifyTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: SpotifyTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.speaker_group, color: SpotifyTheme.background, size: 32),
                ),
                const SizedBox(height: 16),
                Text('Phiên nghe nhạc đã chuyển', style: SpotifyTheme.headingSmall, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text('Đang phát trên thiết bị khác', style: SpotifyTheme.bodyMedium, textAlign: TextAlign.center),
                if (songInfo['songName'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    songInfo['songName'],
                    style: SpotifyTheme.bodySmall,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đã hiểu'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void switchToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _currentIndex = index);
    }
  }

  void switchToHomeTab() => switchToTab(0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: List.generate(
                _screens.length,
                (index) => Navigator(
                  key: _navigatorKeys[index],
                  onGenerateRoute: (settings) {
                    return MaterialPageRoute(builder: (_) => _screens[index]);
                  },
                ),
              ),
            ),
          ),
          // Mini Player
          _buildMiniPlayer(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildMiniPlayer() {
    return StreamBuilder<Song?>(
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
                height: 64,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SpotifyTheme.cardHover,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            // Song image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                "https://difficulties-filled-did-announce.trycloudflare.com${song.imageUrl}",
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 48,
                                  height: 48,
                                  color: SpotifyTheme.card,
                                  child: const Icon(Icons.music_note, color: SpotifyTheme.textMuted),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Song info
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.name ?? "Không rõ tên",
                                    style: SpotifyTheme.bodyLarge.copyWith(fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Nghệ sĩ",
                                    style: SpotifyTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Device icon
                            IconButton(
                              icon: const Icon(Icons.speaker_group_outlined, size: 22),
                              color: SpotifyTheme.textSecondary,
                              onPressed: () {},
                            ),
                            // Play/Pause button
                            IconButton(
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 32,
                              ),
                              color: SpotifyTheme.textPrimary,
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
                    // Progress bar
                    StreamBuilder<Duration>(
                      stream: _audioService.player.positionStream,
                      builder: (context, posSnap) {
                        final position = posSnap.data ?? Duration.zero;
                        final duration = _audioService.player.duration ?? Duration.zero;
                        final progress = duration.inMilliseconds > 0
                            ? position.inMilliseconds / duration.inMilliseconds
                            : 0.0;

                        return Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1),
                          ),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: SpotifyTheme.textMuted.withOpacity(0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(SpotifyTheme.textPrimary),
                            minHeight: 2,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: SpotifyTheme.background,
        border: Border(
          top: BorderSide(color: SpotifyTheme.divider.withOpacity(0.1)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_filled, Icons.home_outlined, 'Trang chủ'),
              _buildNavItem(1, Icons.search, Icons.search, 'Tìm kiếm'),
              _buildNavItem(2, Icons.library_music, Icons.library_music_outlined, 'Thư viện'),
              _buildNavItem(3, Icons.person, Icons.person_outline, 'Cá nhân'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? SpotifyTheme.textPrimary : SpotifyTheme.textMuted,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? SpotifyTheme.textPrimary : SpotifyTheme.textMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
