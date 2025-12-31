import 'package:flutter/material.dart';
import '../services/music_api_service.dart';
import '../services/audio_player_service.dart';
import '../services/playlist_service.dart';
import '../services/auth_service.dart';
import '../services/album_service.dart';
import '../theme.dart';
import 'album_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<Song>>? _songsFuture;
  Future<List<Album>>? _albumsFuture;
  final AudioPlayerService _audioService = AudioPlayerService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _songsFuture = ApiService.fetchSongs();
    _albumsFuture = AlbumService.fetchAlbums();
    _audioService.init();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  Future<void> _showPlaylistSelection(Song song) async {
    final user = _authService.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text("Bạn cần đăng nhập để thêm bài hát vào playlist."),
          backgroundColor: SpotifyTheme.cardHover,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    List<Playlist> playlists = [];
    try {
      playlists = await PlaylistService.fetchAllPlaylists(user.token);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Lỗi tải playlist: $e"),
            backgroundColor: SpotifyTheme.error),
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
                          child: const Icon(Icons.music_note,
                              color: SpotifyTheme.textSecondary),
                        ),
                        title:
                            Text(playlist.name, style: SpotifyTheme.bodyLarge),
                        onTap: () async {
                          Navigator.pop(context);
                          await _addSongToPlaylist(
                              song, playlist.id, user.token);
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
                    child:
                        const Icon(Icons.add, color: SpotifyTheme.textPrimary),
                  ),
                  title:
                      Text("Tạo playlist mới", style: SpotifyTheme.bodyLarge),
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
          style: const TextStyle(color: SpotifyTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: "Nhập tên playlist",
            hintStyle: TextStyle(color: SpotifyTheme.textMuted),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: Text("Hủy",
                style: TextStyle(color: SpotifyTheme.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Tạo",
                style: TextStyle(color: SpotifyTheme.primary)),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              try {
                final playlist = await PlaylistService.createPlaylist(
                    name, token,
                    songId: song.id!);
                await _addSongToPlaylist(song, playlist.id, token);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text("Lỗi tạo playlist: $e"),
                      backgroundColor: SpotifyTheme.error),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addSongToPlaylist(
      Song song, String playlistId, String token) async {
    try {
      await PlaylistService.addSongToPlaylist(playlistId, song.id!, token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Đã thêm '${song.name}' vào playlist!"),
          backgroundColor: SpotifyTheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Lỗi khi thêm bài hát: $e"),
            backgroundColor: SpotifyTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header with greeting
            // SliverToBoxAdapter(
            //   child: Padding(
            //     padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            //     child: Row(
            //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //       children: [
            //         Text(_getGreeting(), style: SpotifyTheme.headingMedium),
            //         Row(
            //           children: [
            //             IconButton(
            //               icon: const Icon(Icons.notifications_outlined, color: SpotifyTheme.textPrimary),
            //               onPressed: () {},
            //             ),
            //             IconButton(
            //               icon: const Icon(Icons.history, color: SpotifyTheme.textPrimary),
            //               onPressed: () {},
            //             ),
            //             IconButton(
            //               icon: const Icon(Icons.settings_outlined, color: SpotifyTheme.textPrimary),
            //               onPressed: () {},
            //             ),
            //           ],
            //         ),
            //       ],
            //     ),
            //   ),
            // ),

            // Albums Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child:
                    Text("Albums phổ biến", style: SpotifyTheme.headingSmall),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: FutureBuilder<List<Album>>(
                  future: _albumsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: SpotifyTheme.primary));
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return Center(
                        child: Text("Không có album nào",
                            style: SpotifyTheme.bodyMedium),
                      );
                    }

                    final albums = snapshot.data!;
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: albums.length,
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(
                                  albumId: album.id, albumName: album.name),
                            ),
                          ),
                          child: Container(
                            width: 150,
                            margin: const EdgeInsets.only(right: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: album.imageUrl != null &&
                                            album.imageUrl!.isNotEmpty
                                        ? Image.network(
                                            album.imageUrl!.startsWith('http')
                                                ? album.imageUrl!
                                                : 'https://civil-specialist-usual-main.trycloudflare.com${album.imageUrl}',
                                            width: 150,
                                            height: 150,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _buildAlbumPlaceholder(),
                                          )
                                        : _buildAlbumPlaceholder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  album.name,
                                  style: SpotifyTheme.bodyLarge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Songs Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                child: Text("Dành cho bạn", style: SpotifyTheme.headingSmall),
              ),
            ),

            // Songs Grid
            FutureBuilder<List<Song>>(
              future: _songsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                            color: SpotifyTheme.primary),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text("Không có bài hát nào",
                            style: SpotifyTheme.bodyMedium),
                      ),
                    ),
                  );
                }

                final songs = snapshot.data!;
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = songs[index];
                        return _buildSongTile(song, songs);
                      },
                      childCount: songs.length,
                    ),
                  ),
                );
              },
            ),

            // Bottom padding for mini player
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumPlaceholder() {
    return Container(
      width: 150,
      height: 150,
      color: SpotifyTheme.cardHover,
      child: const Icon(Icons.album, color: SpotifyTheme.textMuted, size: 48),
    );
  }

  Widget _buildSongTile(Song song, List<Song> allSongs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            try {
              await _audioService.playSong(song, songsAsPlaylist: allSongs);
            } catch (e) {
              debugPrint('HomeScreen: playSong error: $e');
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                // Song image
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    "https://civil-specialist-usual-main.trycloudflare.com${song.imageUrl}",
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: SpotifyTheme.cardHover,
                      child: const Icon(Icons.music_note,
                          color: SpotifyTheme.textMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Song info
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
                    ],
                  ),
                ),
                // More options button
                IconButton(
                  icon: const Icon(Icons.more_vert,
                      color: SpotifyTheme.textSecondary),
                  onPressed: () => _showPlaylistSelection(song),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
