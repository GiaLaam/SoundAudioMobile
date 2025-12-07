import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/music_api_service.dart';
import '../services/audio_player_service.dart';
import '../services/playlist_service.dart';
import '../services/auth_service.dart';
import '../services/album_service.dart';
import 'album_detail_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

  Future<void> _showPlaylistSelection(Song song) async {
    final user = _authService.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bạn cần đăng nhập để thêm bài hát vào playlist."),
          backgroundColor: Colors.orange,
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
        SnackBar(content: Text("Lỗi tải playlist: $e"), backgroundColor: Colors.red),
      );
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                "Chọn playlist của bạn",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 20),
              if (playlists.isNotEmpty)
                ...playlists.map((playlist) {
                  return ListTile(
                    leading: const Icon(Icons.playlist_play, color: Colors.white70),
                    title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _addSongToPlaylist(song, playlist.id, user.token);
                    },
                  );
                }),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.add, color: Colors.greenAccent),
                title: const Text("Tạo playlist mới", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showCreatePlaylistDialog(song, user.token);
                },
              ),
            ],
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
        backgroundColor: const Color(0xFF121212),
        title: const Text("Tạo playlist mới", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Nhập tên playlist",
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Hủy", style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Tạo", style: TextStyle(color: Colors.greenAccent)),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context);

              try {
                final playlist = await PlaylistService.createPlaylist(
                  name,
                  token,
                  songId: song.id!,
                );
                await _addSongToPlaylist(song, playlist.id, token);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Lỗi tạo playlist: $e"), backgroundColor: Colors.red),
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
        SnackBar(content: Text("Đã thêm '${song.name}' vào playlist!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi thêm bài hát: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "SoundAudio",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section: Albums
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Albums",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // Albums Grid
              FutureBuilder<List<Album>>(
                future: _albumsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(color: Colors.greenAccent),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "Lỗi tải albums: ${snapshot.error}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "Không có album nào.",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }

                  final albums = snapshot.data!;
                  return SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: albums.length,
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AlbumDetailScreen(
                                  albumId: album.id,
                                  albumName: album.name,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Album cover
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: album.imageUrl != null && album.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          album.imageUrl!.startsWith('http')
                                              ? album.imageUrl!
                                              : 'https://willing-baltimore-brunette-william.trycloudflare.com${album.imageUrl}',
                                          width: 160,
                                          height: 160,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 160,
                                            height: 160,
                                            color: Colors.grey[850],
                                            child: const Icon(Icons.album, color: Colors.white54, size: 60),
                                          ),
                                        )
                                      : Container(
                                          width: 160,
                                          height: 160,
                                          color: Colors.grey[850],
                                          child: const Icon(Icons.album, color: Colors.white54, size: 60),
                                        ),
                                ),
                                const SizedBox(height: 8),
                                // Album name
                                Text(
                                  album.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (album.songCount != null)
                                  Text(
                                    '${album.songCount} bài hát',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Section: All Songs
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Tất cả bài hát",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Songs List
              FutureBuilder<List<Song>>(
                future: _songsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(color: Colors.greenAccent),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "Lỗi tải nhạc: ${snapshot.error}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "Không có bài hát nào.",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  }

                  final songs = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              "https://willing-baltimore-brunette-william.trycloudflare.com${song.imageUrl}",
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[850],
                                child: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                            ),
                          ),
                          title: Text(
                            song.name ?? "Không rõ tên",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          trailing: IconButton(
                            icon: const Icon(FontAwesomeIcons.plus, color: Colors.greenAccent),
                            onPressed: () => _showPlaylistSelection(song),
                          ),
                          onTap: () async {
                            try {
                              await _audioService.playSong(song, songsAsPlaylist: songs);
                            } catch (e) {
                              print('HomeScreen: playSong error: $e');
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
