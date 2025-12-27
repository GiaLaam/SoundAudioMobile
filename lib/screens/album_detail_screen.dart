import 'package:flutter/material.dart';
import '../services/album_service.dart';
import '../services/music_api_service.dart';
import '../services/audio_player_service.dart';
import '../services/playlist_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String albumId;
  final String albumName;

  const AlbumDetailScreen({
    Key? key,
    required this.albumId,
    required this.albumName,
  }) : super(key: key);

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final AudioPlayerService _audioService = AudioPlayerService();
  final AuthService _authService = AuthService();
  Album? _albumDetails;
  List<Song> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbumData();
    _audioService.init();
  }

  Future<void> _loadAlbumData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        AlbumService.fetchAlbumDetails(widget.albumId),
        AlbumService.fetchSongsByAlbum(widget.albumId),
      ]);
      setState(() {
        _albumDetails = results[0] as Album;
        _songs = results[1] as List<Song>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải album: $e'), backgroundColor: SpotifyTheme.error),
        );
      }
    }
  }

  Future<void> _showPlaylistSelection(Song song) async {
    final user = _authService.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bạn cần đăng nhập để thêm bài hát vào playlist.")),
      );
      return;
    }

    List<Playlist> playlists = [];
    try {
      playlists = await PlaylistService.fetchAllPlaylists(user.token);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi tải playlist: $e"), backgroundColor: SpotifyTheme.error),
      );
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SpotifyTheme.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text("Thêm vào playlist", style: SpotifyTheme.headingSmall),
                const SizedBox(height: 16),
                if (playlists.isNotEmpty)
                  ...playlists.map((playlist) => ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: SpotifyTheme.cardHover,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.music_note, color: SpotifyTheme.textSecondary),
                    ),
                    title: Text(playlist.name, style: SpotifyTheme.bodyLarge),
                    onTap: () async {
                      Navigator.pop(context);
                      await _addSongToPlaylist(song, playlist.id, user.token);
                    },
                  )),
                const Divider(color: SpotifyTheme.divider, height: 24),
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: SpotifyTheme.cardHover,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.add, color: SpotifyTheme.textPrimary),
                  ),
                  title: Text("Tạo playlist mới", style: SpotifyTheme.bodyLarge),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePlaylistDialog(song, user.token);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreatePlaylistDialog(Song song, String token) async {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyTheme.surface,
        title: Text("Tạo playlist mới", style: SpotifyTheme.headingSmall),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: SpotifyTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: "Nhập tên playlist",
            hintStyle: TextStyle(color: SpotifyTheme.textMuted),
          ),
        ),
        actions: [
          TextButton(
            child: Text("Hủy", style: TextStyle(color: SpotifyTheme.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Tạo", style: TextStyle(color: SpotifyTheme.primary)),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              try {
                final playlist = await PlaylistService.createPlaylist(name, token, songId: song.id!);
                await _addSongToPlaylist(song, playlist.id, token);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Lỗi tạo playlist: $e"), backgroundColor: SpotifyTheme.error),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addSongToPlaylist(Song song, String playlistId, String token) async {
    try {
      await PlaylistService.addSongToPlaylist(playlistId, song.id!, token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã thêm '${song.name}' vào playlist!"), backgroundColor: SpotifyTheme.primary),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi thêm bài hát: $e"), backgroundColor: SpotifyTheme.error),
      );
    }
  }

  String _getAlbumImageUrl() {
    if (_albumDetails?.imageUrl == null) return '';
    final img = _albumDetails!.imageUrl!;
    if (img.startsWith('http')) return img;
    return 'https://difficulties-filled-did-announce.trycloudflare.com${img.startsWith('/') ? img : '/$img'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SpotifyTheme.primary))
          : CustomScrollView(
              slivers: [
                // Header with album art
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
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_albumDetails?.imageUrl != null)
                          Image.network(
                            _getAlbumImageUrl(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: SpotifyTheme.cardHover,
                              child: const Icon(Icons.album, color: SpotifyTheme.textMuted, size: 80),
                            ),
                          )
                        else
                          Container(
                            color: SpotifyTheme.cardHover,
                            child: const Icon(Icons.album, color: SpotifyTheme.textMuted, size: 80),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                SpotifyTheme.background.withOpacity(0.8),
                                SpotifyTheme.background,
                              ],
                              stops: const [0.3, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Album info
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _albumDetails?.name ?? widget.albumName,
                          style: SpotifyTheme.headingMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 12,
                              backgroundColor: SpotifyTheme.cardHover,
                              child: Icon(Icons.person, size: 14, color: SpotifyTheme.textSecondary),
                            ),
                            const SizedBox(width: 8),
                            Text('Nghệ sĩ', style: SpotifyTheme.bodyMedium),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${_songs.length} bài hát', style: SpotifyTheme.bodySmall),
                        const SizedBox(height: 16),
                        // Action buttons
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.favorite_border, color: SpotifyTheme.textSecondary),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.download_outlined, color: SpotifyTheme.textSecondary),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert, color: SpotifyTheme.textSecondary),
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
                _songs.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Text('Không có bài hát nào trong album.', style: SpotifyTheme.bodyMedium),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final song = _songs[index];
                            return _buildSongTile(song, index);
                          },
                          childCount: _songs.length,
                        ),
                      ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildSongTile(Song song, int index) {
    String? imageUrl;
    if (song.imageUrl != null && song.imageUrl!.isNotEmpty) {
      imageUrl = song.imageUrl!.startsWith('http')
          ? song.imageUrl
          : 'https://difficulties-filled-did-announce.trycloudflare.com${song.imageUrl}';
    } else if (_albumDetails?.imageUrl != null) {
      imageUrl = _getAlbumImageUrl();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          try {
            await _audioService.playSong(song, songsAsPlaylist: _songs);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi phát nhạc: $e'), backgroundColor: SpotifyTheme.error),
              );
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Song image
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: 12),
              // Song info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.name ?? 'Unknown',
                      style: SpotifyTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('Nghệ sĩ', style: SpotifyTheme.bodySmall),
                  ],
                ),
              ),
              // More options
              IconButton(
                icon: const Icon(Icons.more_vert, color: SpotifyTheme.textSecondary, size: 20),
                onPressed: () => _showPlaylistSelection(song),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      color: SpotifyTheme.cardHover,
      child: const Icon(Icons.music_note, color: SpotifyTheme.textMuted, size: 24),
    );
  }
}
