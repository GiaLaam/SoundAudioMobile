import 'package:flutter/material.dart';
import '../services/music_api_service.dart';
import '../services/audio_player_service.dart';
import '../theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Song> _searchResults = [];
  List<Song> _allSongs = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  // Genre colors for browse cards
  final List<Map<String, dynamic>> _genres = [
    {'name': 'Nhạc Việt', 'color': const Color(0xFFE13300)},
    {'name': 'K-Pop', 'color': const Color(0xFF148A08)},
    {'name': 'US-UK', 'color': const Color(0xFFE8115B)},
    {'name': 'Indie', 'color': const Color(0xFF8400E7)},
    {'name': 'R&B', 'color': const Color(0xFF1E3264)},
    {'name': 'EDM', 'color': const Color(0xFFE1118B)},
    {'name': 'Jazz', 'color': const Color(0xFF477D95)},
    {'name': 'Acoustic', 'color': const Color(0xFFBA5D07)},
  ];

  @override
  void initState() {
    super.initState();
    _loadAllSongs();
  }

  Future<void> _loadAllSongs() async {
    try {
      final songs = await ApiService.fetchSongs();
      setState(() => _allSongs = songs);
    } catch (e) {
      debugPrint("Error loading songs: $e");
    }
  }

  Future<void> _searchSongs(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final filtered = _allSongs
          .where((s) =>
              (s.name ?? '').toLowerCase().contains(query.toLowerCase()) ||
              (s.fileName ?? '').toLowerCase().contains(query.toLowerCase()))
          .toList();
      setState(() => _searchResults = filtered);
    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService();

    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text("Tìm kiếm", style: SpotifyTheme.headingMedium),
              ),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: SpotifyTheme.textPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: _searchSongs,
                    style: const TextStyle(
                      color: SpotifyTheme.background,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Bạn muốn nghe gì?',
                      hintStyle: TextStyle(
                        color: SpotifyTheme.background.withOpacity(0.6),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: SpotifyTheme.background.withOpacity(0.8),
                        size: 24,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: SpotifyTheme.background.withOpacity(0.8)),
                              onPressed: () {
                                _searchController.clear();
                                _searchSongs('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            if (_hasSearched)
              _buildSearchResults(player)
            else
              _buildBrowseSection(),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(AudioPlayerService player) {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(color: SpotifyTheme.primary),
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              children: [
                const Icon(Icons.search_off, size: 64, color: SpotifyTheme.textMuted),
                const SizedBox(height: 16),
                Text(
                  'Không tìm thấy kết quả cho "${_searchController.text}"',
                  style: SpotifyTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final song = _searchResults[index];
            return _buildSongTile(song, player);
          },
          childCount: _searchResults.length,
        ),
      ),
    );
  }

  Widget _buildSongTile(Song song, AudioPlayerService player) {
    final imageUrl = "https://difficulties-filled-did-announce.trycloudflare.com${song.imageUrl ?? ''}";

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await player.setPlaylist(_searchResults);
          await player.playSong(song);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
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
                      song.name ?? "Unknown",
                      style: SpotifyTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: SpotifyTheme.textMuted.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            'BÀI HÁT',
                            style: SpotifyTheme.bodySmall.copyWith(fontSize: 9),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nghệ sĩ',
                            style: SpotifyTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrowseSection() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text("Duyệt tìm tất cả", style: SpotifyTheme.headingSmall),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.8,
            ),
            itemCount: _genres.length,
            itemBuilder: (context, index) {
              final genre = _genres[index];
              return _buildGenreCard(genre['name'], genre['color']);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGenreCard(String name, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -10,
            child: Transform.rotate(
              angle: 0.4,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(-2, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.music_note, color: Colors.white54, size: 30),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
