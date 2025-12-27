import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/playlist_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'playlist_detail_screen.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final PlaylistService _playlistService = PlaylistService();
  final AuthService _authService = AuthService();
  List<Playlist> _playlists = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final playlists = await _playlistService.getUserPlaylists();
      if (mounted) {
        setState(() => _playlists = playlists);
      }
    } catch (e) {
      debugPrint("Lỗi khi tải playlist: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi khi tải playlist: $e"),
            backgroundColor: SpotifyTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCreatePlaylistDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Đặt tên playlist của bạn', style: SpotifyTheme.headingSmall),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: SpotifyTheme.textPrimary, fontSize: 18),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'Playlist của tôi',
            hintStyle: TextStyle(color: SpotifyTheme.textMuted),
            filled: false,
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: SpotifyTheme.textMuted),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: SpotifyTheme.primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: SpotifyTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập tên playlist')),
                );
                return;
              }

              Navigator.pop(context);
              final user = _authService.currentUser;
              if (user == null) return;

              try {
                final newPlaylist = await PlaylistService.createPlaylist(name, user.token);
                setState(() => _playlists.insert(0, newPlaylist));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Tạo playlist thành công'),
                      backgroundColor: SpotifyTheme.primary,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi khi tạo playlist: $e')),
                  );
                }
              }
            },
            child: const Text('Tạo', style: TextStyle(color: SpotifyTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: SpotifyTheme.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: SpotifyTheme.cardHover,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.library_music, size: 48, color: SpotifyTheme.textMuted),
                  ),
                  const SizedBox(height: 24),
                  Text('Thư viện của bạn', style: SpotifyTheme.headingMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Đăng nhập để xem playlist đã lưu và tạo playlist mới',
                    style: SpotifyTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpotifyTheme.textPrimary,
                      foregroundColor: SpotifyTheme.background,
                      minimumSize: const Size(200, 48),
                    ),
                    child: const Text('Đăng nhập'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Thư viện", style: SpotifyTheme.headingMedium),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.search, color: SpotifyTheme.textPrimary),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: SpotifyTheme.textPrimary),
                          onPressed: _showCreatePlaylistDialog,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Filter chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildFilterChip('Playlist', true),
                    _buildFilterChip('Nghệ sĩ', false),
                    _buildFilterChip('Album', false),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Playlist list
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: SpotifyTheme.primary),
                  ),
                ),
              )
            else if (_playlists.isEmpty)
              SliverToBoxAdapter(
                child: _buildEmptyState(),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPlaylistTile(_playlists[index]),
                  childCount: _playlists.length,
                ),
              ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {},
        backgroundColor: SpotifyTheme.cardHover,
        selectedColor: SpotifyTheme.primary,
        labelStyle: TextStyle(
          color: selected ? SpotifyTheme.background : SpotifyTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            const Icon(Icons.library_music_outlined, size: 64, color: SpotifyTheme.textMuted),
            const SizedBox(height: 16),
            Text('Chưa có playlist nào', style: SpotifyTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              'Tạo playlist đầu tiên của bạn',
              style: SpotifyTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _showCreatePlaylistDialog,
              child: const Text('Tạo playlist'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(Playlist playlist) {
    final songCount = playlist.musicIds.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlaylistDetailScreen(
                playlistId: playlist.id,
                playlistName: playlist.name,
              ),
            ),
          ).then((_) => _loadPlaylists());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Playlist cover
              Container(
                width: 64,
                height: 64,
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
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.music_note, color: SpotifyTheme.textMuted, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: SpotifyTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.push_pin, size: 12, color: SpotifyTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Playlist • $songCount bài hát',
                          style: SpotifyTheme.bodySmall,
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
}
