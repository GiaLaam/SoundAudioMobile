import 'package:flutter/material.dart';
import '../services/recently_played_service.dart';
import '../services/audio_player_service.dart';
import '../services/music_api_service.dart';
import '../theme.dart';

class RecentlyPlayedScreen extends StatefulWidget {
  const RecentlyPlayedScreen({super.key});

  @override
  State<RecentlyPlayedScreen> createState() => _RecentlyPlayedScreenState();
}

class _RecentlyPlayedScreenState extends State<RecentlyPlayedScreen> {
  final RecentlyPlayedService _recentlyPlayedService = RecentlyPlayedService();
  final AudioPlayerService _audioService = AudioPlayerService();
  List<Song> _songs = [];

  @override
  void initState() {
    super.initState();
    _loadRecentlyPlayed();
  }

  void _loadRecentlyPlayed() {
    setState(() {
      _songs = _recentlyPlayedService.getRecent(limit: 50);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      appBar: AppBar(
        backgroundColor: SpotifyTheme.background,
        title: Text('Đã nghe gần đây', style: SpotifyTheme.headingSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SpotifyTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: SpotifyTheme.textSecondary),
              onPressed: _showClearDialog,
            ),
        ],
      ),
      body: _songs.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _songs.length,
              itemBuilder: (context, index) => _buildSongTile(_songs[index]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 64, color: SpotifyTheme.textMuted),
            const SizedBox(height: 16),
            Text('Chưa có bài hát nào', style: SpotifyTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              'Các bài hát bạn nghe sẽ xuất hiện ở đây',
              style: SpotifyTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongTile(Song song) {
    final imageUrl = song.imageUrl != null && song.imageUrl!.isNotEmpty
        ? (song.imageUrl!.startsWith('http')
            ? song.imageUrl!
            : 'https://civil-specialist-usual-main.trycloudflare.com${song.imageUrl}')
        : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await _audioService.playSong(song, songsAsPlaylist: _songs);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.name ?? 'Không rõ tên',
                      style: SpotifyTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('Nghệ sĩ', style: SpotifyTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: SpotifyTheme.textSecondary, size: 20),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: SpotifyTheme.cardHover,
      child: const Icon(Icons.music_note, color: SpotifyTheme.textMuted),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyTheme.surface,
        title: Text('Xóa lịch sử', style: SpotifyTheme.headingSmall),
        content: Text(
          'Bạn có chắc muốn xóa tất cả lịch sử nghe nhạc?',
          style: SpotifyTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: SpotifyTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _recentlyPlayedService.clear();
              _loadRecentlyPlayed();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Đã xóa lịch sử'),
                    backgroundColor: SpotifyTheme.primary,
                  ),
                );
              }
            },
            child: const Text('Xóa', style: TextStyle(color: SpotifyTheme.error)),
          ),
        ],
      ),
    );
  }
}
