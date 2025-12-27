import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../services/music_api_service.dart';
import '../theme.dart';
import '../screens/player_screen.dart';
import 'playback_notification_banner.dart';
import 'devices_dialog.dart';
import '../services/signalr_service.dart';

/// Widget này bọc bất kỳ màn hình nào và thêm miniplayer + bottom nav bar
class ScaffoldWithMiniPlayer extends StatefulWidget {
  final Widget child;
  final int? currentIndex;
  final Function(int)? onNavigationTap;
  final bool showBottomNav;

  const ScaffoldWithMiniPlayer({
    Key? key,
    required this.child,
    this.currentIndex,
    this.onNavigationTap,
    this.showBottomNav = true,
  }) : super(key: key);

  @override
  State<ScaffoldWithMiniPlayer> createState() => _ScaffoldWithMiniPlayerState();
}

class _ScaffoldWithMiniPlayerState extends State<ScaffoldWithMiniPlayer> {
  bool _showBanner = false;
  String? _remoteDeviceName;
  String? _remoteSongName;

  @override
  void initState() {
    super.initState();
    _listenToRemotePlayback();
  }

  void _listenToRemotePlayback() {
    // Lắng nghe khi có thiết bị khác đang phát nhạc
    
    // TODO: Thêm stream để lắng nghe remote playback từ SignalR
    // Tạm thời giả lập - bạn sẽ cần tích hợp với SignalR service
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showBanner = true;
          _remoteDeviceName = "iPhone của bạn";
          _remoteSongName = "Playing from another device";
        });
      }
    });
  }

  void _showDevicesDialog() async {
    final signalRService = SignalRService();
    final devices = await signalRService.getAvailableDevices();
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => DevicesDialog(
        currentDeviceId: signalRService.currentDeviceId ?? 'unknown',
        currentDeviceName: signalRService.currentDeviceName ?? 'This Device',
        availableDevices: devices.map((d) => {
          'deviceId': d.deviceId,
          'deviceName': d.deviceName,
          'isActive': d.isActive,
        }).toList(),
        onDeviceSelected: (deviceId) async {
          // Chuyển phát nhạc sang thiết bị được chọn
          final audioService = AudioPlayerService();
          final currentSong = audioService.currentSong;
          
          if (currentSong != null && currentSong.id != null) {
            await signalRService.transferPlayback(
              deviceId,
              currentSong.id!,
              audioService.player.position,
              audioService.player.playing,
            );
            
            // Ẩn banner khi chuyển về thiết bị này
            if (deviceId == signalRService.currentDeviceId) {
              setState(() {
                _showBanner = false;
              });
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioService = AudioPlayerService();

    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: Stack(
        children: [
          Column(
            children: [
              // Nội dung chính
              Expanded(
                child: widget.child,
              ),

              // Mini Player
              StreamBuilder<Song?>(
                stream: audioService.currentSongStream,
                builder: (context, songSnap) {
                  final song = songSnap.data;
                  if (song == null) return const SizedBox.shrink();

                  return StreamBuilder<bool>(
                    stream: audioService.isPlayingStream,
                    builder: (context, playSnap) {
                      final isPlaying = playSnap.data ?? false;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(
                                audioPlayer: audioService.player,
                                currentSong: song,
                                isPlaying: isPlaying,
                                onTogglePlay: () {
                                  if (isPlaying) {
                                    audioService.pause();
                                  } else {
                                    audioService.play();
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
                                  "https://difficulties-filled-did-announce.trycloudflare.com${song.imageUrl}",
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
                              // Nút Devices
                              IconButton(
                                icon: const Icon(
                                  Icons.devices,
                                  color: Colors.white70,
                                  size: 24,
                                ),
                                onPressed: _showDevicesDialog,
                              ),
                              IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause_circle : Icons.play_circle,
                                  color: Colors.greenAccent,
                                  size: 40,
                                ),
                                onPressed: () {
                                  if (isPlaying) {
                                    audioService.pause();
                                  } else {
                                    audioService.play();
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

          // Banner thông báo khi nhạc đang phát ở thiết bị khác
          if (_showBanner)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: PlaybackNotificationBanner(
                deviceName: _remoteDeviceName ?? 'Unknown Device',
                songName: _remoteSongName,
                onTap: _showDevicesDialog,
                onDismiss: () {
                  setState(() {
                    _showBanner = false;
                  });
                },
              ),
            ),
        ],
      ),

      // Bottom Navigation Bar (optional)
      bottomNavigationBar: widget.showBottomNav && widget.currentIndex != null
          ? BottomNavigationBar(
              backgroundColor: SpotifyTheme.background,
              selectedItemColor: SpotifyTheme.primary,
              unselectedItemColor: Colors.grey,
              currentIndex: widget.currentIndex!,
              type: BottomNavigationBarType.fixed,
              onTap: widget.onNavigationTap,
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.home_filled), label: 'Trang chủ'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.search), label: 'Tìm kiếm'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.library_music), label: 'Thư viện'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.person), label: 'Cá nhân'),
              ],
            )
          : null,
    );
  }
}
