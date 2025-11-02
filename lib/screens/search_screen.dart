import 'package:flutter/material.dart';
import '../services/music_api_service.dart';
import '../services/audio_player_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isLoading = false;

  Future<void> _searchSongs(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final allSongs = await ApiService.fetchSongs();
      final filtered = allSongs
          .where((s) =>
              (s.name ?? '').toLowerCase().contains(query.toLowerCase()) ||
              (s.fileName ?? '').toLowerCase().contains(query.toLowerCase()))
          .toList();

      setState(() => _searchResults = filtered);
    } catch (e) {
      debugPrint("❌ Lỗi tìm kiếm: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Tìm Kiếm",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // 🔍 Ô tìm kiếm
              TextField(
                controller: _searchController,
                onChanged: _searchSongs,
                decoration: InputDecoration(
                  hintText: 'Bạn muốn nghe gì?',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),

              const SizedBox(height: 25),

              // 🧠 Danh sách kết quả
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                        ? const Center(
                            child: Text(
                              "",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final song = _searchResults[index];
                              final imageUrl =
                                  "http://192.168.1.7:5289${song.imageUrl ?? ''}";

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    imageUrl,
                                    width: 55,
                                    height: 55,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, _, __) => Container(
                                      width: 55,
                                      height: 55,
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.music_note,
                                          color: Colors.white),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  song.name ?? "Unknown song",
                                  style: const TextStyle(color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  song.fileName ?? "Unknown artist",
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                onTap: () async {
                                  await player.setPlaylist(_searchResults);
                                  await player.playSong(song);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
