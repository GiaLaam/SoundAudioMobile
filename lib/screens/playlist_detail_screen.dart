import 'package:flutter/material.dart';
import '../services/playlist_service.dart';
import '../services/audio_player_service.dart';
import '../services/auth_service.dart';
import '../services/music_api_service.dart';
import '../theme.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final String playlistName;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final AudioPlayerService _audioService = AudioPlayerService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  List<Song> _songs = [];
  String _playlistName = "";

  @override
  void initState() {
    super.initState();
    _playlistName = widget.playlistName;
    _loadPlaylistDetails();
    _audioService.init();
  }

  Future<void> _loadPlaylistDetails() async {
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final playlist = await PlaylistService.fetchPlaylistDetails(widget.playlistId, user.token);
      if (!mounted) return;
      setState(() {
        _songs = playlist.songs;
        _playlistName = playlist.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi tải playlist: $e"), backgroundColor: SpotifyTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _renamePlaylist() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final controller = TextEditingController(text: _playlistName);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyTheme.surface,
        title: Text("Đổi tên playlist", style: SpotifyTheme.headingSmall),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: SpotifyTheme.textPrimary),
          decoration: const InputDecoration(hintText: "Nhập tên mới"),
        ),
        actions: [
          TextButton(
            child: Text("Hủy", style: TextStyle(color: SpotifyTheme.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Lưu", style: TextStyle(color: SpotifyTheme.primary)),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(context);
              try {
                await PlaylistService.renamePlaylist(widget.playlistId, newName, user.token);
                setState(() => _playlistName = newName);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text("Đổi tên thành công"), backgroundColor: SpotifyTheme.primary),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Lỗi đổi tên: $e"), backgroundColor: SpotifyTheme.error),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlaylist() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyTheme.surface,
        title: Text("Xóa playlist", style: SpotifyTheme.headingSmall),
        content: Text("Bạn có chắc muốn xóa playlist này không?", style: SpotifyTheme.bodyMedium),
        actions: [
          TextButton(
            child: Text("Hủy", style: TextStyle(color: SpotifyTheme.textSecondary)),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text("Xóa", style: TextStyle(color: SpotifyTheme.error)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await PlaylistService.deletePlaylist(widget.playlistId, user.token);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text("Đã xóa playlist"), backgroundColor: SpotifyTheme.primary),
        );
        Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi xóa playlist: $e"), backgroundColor: SpotifyTheme.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: SpotifyTheme.background,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: SpotifyTheme.textPrimary, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, color: SpotifyTheme.textPrimary, size: 20),
                ),
                color: SpotifyTheme.surface,
                onSelected: (value) {
                  if (value == 'rename') _renamePlaylist();
                  else if (value == 'delete') _deletePlaylist();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, color: SpotifyTheme.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Text("Đổi tên", style: SpotifyTheme.bodyLarge),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, color: SpotifyTheme.error, size: 20),
                        const SizedBox(width: 12),
                        Text("Xóa", style: SpotifyTheme.bodyLarge.copyWith(color: SpotifyTheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF535353),
                      SpotifyTheme.background,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Playlist cover
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            SpotifyTheme.cardHover,
                            SpotifyTheme.card,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.music_note, color: SpotifyTheme.textMuted, size: 64),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Playlist info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_playlistName, style: SpotifyTheme.headingMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: SpotifyTheme.cardHover,
                        child: Icon(Icons.person, size: 14, color: SpotifyTheme.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text('Playlist của bạn', style: SpotifyTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${_songs.length} bài hát', style: SpotifyTheme.bodySmall),
                  const SizedBox(height: 16),
                  // Action buttons
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.download_outlined, color: SpotifyTheme.textSecondary),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_add_outlined, color: SpotifyTheme.textSecondary),
                        onPressed: () {},
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.shuffle, color: SpotifyTheme.primary),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _songs.isNotEmpty
                            ? () async {
                                await _audioService.setPlaylist(_songs);
                                await _audioService.playSong(_songs[0]);
                              }
                            : null,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: SpotifyTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow, color: SpotifyTheme.background, size: 32),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Songs list
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: SpotifyTheme.primary)),
            )
          else if (_songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.music_off, size: 64, color: SpotifyTheme.textMuted),
                    const SizedBox(height: 16),
                    Text('Playlist trống', style: SpotifyTheme.bodyLarge),
                    const SizedBox(height: 8),
                    Text('Thêm bài hát để bắt đầu', style: SpotifyTheme.bodyMedium),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildSongTile(_songs[index]),
                childCount: _songs.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSongTile(Song song) {
    final imageUrl = "https://civil-specialist-usual-main.trycloudflare.com${song.imageUrl}";

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          try {
            await _audioService.playSong(song, songsAsPlaylist: _songs);
          } catch (e) {
            debugPrint("Lỗi playSong: $e");
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: SpotifyTheme.cardHover,
                    child: const Icon(Icons.music_note, color: SpotifyTheme.textMuted),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.name ?? "Không rõ tên",
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
}
