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

  @override
  void initState() {
    super.initState();
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
        _songs = playlist.songs; // playlist.songs là danh sách Song
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi tải playlist: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.playlistName, style: const TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? const Center(
                  child: Text('Playlist trống', style: TextStyle(color: Colors.white)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          "http://192.168.1.7:5289${song.imageUrl}",
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(song.name ?? "Không rõ tên",
                          style: const TextStyle(color: Colors.white)),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.greenAccent),
                        onPressed: () async {
                          try {
                            await _audioService.playSong(song, songsAsPlaylist: _songs);
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
