import 'package:flutter/material.dart';
import '../services/album_service.dart';
import '../services/music_api_service.dart';
import '../services/audio_player_service.dart';
import '../services/playlist_service.dart';
import '../services/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
          SnackBar(
            content: Text('Lỗi tải album: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : CustomScrollView(
              slivers: [
                // Header với ảnh album
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  backgroundColor: Colors.black,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      _albumDetails?.name ?? widget.albumName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    background: _albumDetails?.imageUrl != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                _albumDetails!.imageUrl!.startsWith('http')
                                    ? _albumDetails!.imageUrl!
                                    : 'https://willing-baltimore-brunette-william.trycloudflare.com${_albumDetails!.imageUrl!.startsWith('/') ? _albumDetails!.imageUrl : '/${_albumDetails!.imageUrl}'}',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey[850],
                                  child: const Icon(Icons.album, color: Colors.white54, size: 100),
                                ),
                              ),
                              // Gradient overlay
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            color: Colors.grey[850],
                            child: const Icon(Icons.album, color: Colors.white54, size: 100),
                          ),
                  ),
                ),

                // Thông tin album
                if (_albumDetails?.description != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _albumDetails!.description!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),

                // Nút Play All
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton.icon(
                      onPressed: _songs.isNotEmpty
                          ? () async {
                              try {
                                await _audioService.setPlaylist(_songs);
                                await _audioService.playSong(_songs[0]);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Lỗi phát nhạc: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      icon: const Icon(Icons.play_circle_filled, size: 28),
                      label: const Text(
                        'Phát tất cả',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ),

                // Danh sách bài hát
                _songs.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'Không có bài hát nào trong album.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final song = _songs[index];
                            
                            // Xác định URL ảnh hiển thị
                            String? displayImageUrl;
                            if (song.imageUrl != null && song.imageUrl!.isNotEmpty) {
                              // Ưu tiên ảnh của bài hát
                              displayImageUrl = song.imageUrl!.startsWith('http')
                                  ? song.imageUrl
                                  : 'https://willing-baltimore-brunette-william.trycloudflare.com${song.imageUrl}';
                            } else if (_albumDetails?.imageUrl != null && _albumDetails!.imageUrl!.isNotEmpty) {
                              // Nếu không có ảnh bài hát, dùng ảnh album
                              displayImageUrl = _albumDetails!.imageUrl!.startsWith('http')
                                  ? _albumDetails!.imageUrl
                                  : 'https://willing-baltimore-brunette-william.trycloudflare.com${_albumDetails!.imageUrl}';
                            }
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Container(
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
                                    child: displayImageUrl != null
                                        ? Image.network(
                                            displayImageUrl,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              width: 60,
                                              height: 60,
                                              color: Colors.grey[850],
                                              child: const Icon(
                                                Icons.music_note,
                                                color: Colors.white54,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[850],
                                            child: const Icon(
                                              Icons.music_note,
                                              color: Colors.white54,
                                            ),
                                          ),
                                  ),
                                  title: Text(
                                    song.name ?? 'Unknown Song',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(FontAwesomeIcons.plus, color: Colors.greenAccent),
                                    onPressed: () => _showPlaylistSelection(song),
                                  ),
                                  onTap: () async {
                                    try {
                                      await _audioService.playSong(song, songsAsPlaylist: _songs);
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Lỗi phát nhạc: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                          childCount: _songs.length,
                        ),
                      ),
              ],
            ),
    );
  }
}