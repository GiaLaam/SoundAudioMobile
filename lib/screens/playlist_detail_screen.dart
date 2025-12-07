import 'package:flutter/material.dart';
import '../services/playlist_service.dart';
import '../services/audio_player_service.dart';
import '../services/auth_service.dart';
import '../services/music_api_service.dart';

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
    if (user == null) {
      print('❌ User chưa đăng nhập');
      return;
    }

    print('🔄 Đang tải chi tiết playlist ${widget.playlistId}...');
    setState(() => _isLoading = true);

    try {
      final playlist =
          await PlaylistService.fetchPlaylistDetails(widget.playlistId, user.token);
      
      print('✅ Đã nhận playlist:');
      print('   - ID: ${playlist.id}');
      print('   - Name: ${playlist.name}');
      print('   - Songs count: ${playlist.songs.length}');
      print('   - MusicIds count: ${playlist.musicIds.length}');
      
      if (playlist.songs.isNotEmpty) {
        print('   - Danh sách bài hát:');
        for (var song in playlist.songs) {
          print('     • ${song.name} (ID: ${song.id})');
        }
      }
      
      if (!mounted) return;

      setState(() {
        _songs = playlist.songs;
        _playlistName = playlist.name;
      });
      
      print('✅ UI đã cập nhật với ${_songs.length} bài hát');
    } catch (e) {
      print('❌ Lỗi tải playlist chi tiết: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi tải playlist: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _renamePlaylist() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final TextEditingController controller =
        TextEditingController(text: _playlistName);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Đổi tên playlist"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nhập tên mới"),
        ),
        actions: [
          TextButton(
            child: const Text("Hủy"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Lưu"),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;

              Navigator.pop(context); // đóng dialog

              try {
                await PlaylistService.renamePlaylist(
                    widget.playlistId, newName, user.token);
                setState(() => _playlistName = newName);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Đổi tên thành công"),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text("Lỗi đổi tên: $e"),
                      backgroundColor: Colors.red),
                );
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
        title: const Text("Xóa playlist"),
        content: const Text("Bạn có chắc muốn xóa playlist này không?"),
        actions: [
          TextButton(
            child: const Text("Hủy"),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Xóa"),
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
          const SnackBar(
              content: Text("Đã xóa playlist"), backgroundColor: Colors.green),
        );

        // Quay về màn hình trước và refresh lại danh sách
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Lỗi xóa playlist: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_playlistName, style: const TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'rename') {
                _renamePlaylist();
              } else if (value == 'delete') {
                _deletePlaylist();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Text("Đổi tên"),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text("Xóa"),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? const Center(
                  child: Text('Playlist trống',
                      style: TextStyle(color: Colors.white)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          "https://willing-baltimore-brunette-william.trycloudflare.com${song.imageUrl}",
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(song.name ?? "Không rõ tên",
                          style: const TextStyle(color: Colors.white)),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_arrow,
                            color: Colors.greenAccent),
                        onPressed: () async {
                          try {
                            await _audioService.playSong(song,
                                songsAsPlaylist: _songs);
                          } catch (e) {
                            print("Lỗi playSong: $e");
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
