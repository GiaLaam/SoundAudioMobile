import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'music_api_service.dart';
class Playlist {
  final String id;
  final String name;
  final String userId;
  final List<Song> songs;
  final List<String> musicIds;

  Playlist({
    required this.id,
    required this.name,
    required this.userId,
    required this.songs,
    required this.musicIds,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final allSongsJson = json['songs'] as List<dynamic>? ?? [];
    final songList = allSongsJson.map((s) => Song.fromJson(s)).toList();
    return Playlist(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      userId: json['userId'] ?? '',
      songs: songList,
      musicIds: List<String>.from(json['musicIds'] ?? []),
    );
  }
}

class PlaylistService {
  static const String baseUrl = 'http://192.168.1.7:5289/api/playlist';
  final AuthService _authService = AuthService();

  /// Lấy danh sách playlist của user
  Future<List<Playlist>> getUserPlaylists() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/user-playlists'),
        headers: {
          'Authorization': 'Bearer ${user.token}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Playlist.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get playlists error: $e');
      return [];
    }
  }

  /// Thêm bài hát vào playlist
  static Future<Playlist> createPlaylist(String name, String token, String songId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name, 'songId': songId}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Không thể tạo playlist (mã ${response.statusCode})");
    }

    final data = jsonDecode(response.body);
    return Playlist.fromJson(data['playlist']);
  }

  static Future<void> addSongToPlaylist(String playlistId, String songId, String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/add-song'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'playlistId': playlistId, 'songId': songId}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Không thể thêm bài hát (mã ${response.statusCode})");
    }
  }

  static Future<void> removeSongFromPlaylist(String playlistId, String songId, String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/remove-song'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'playlistId': playlistId, 'songId': songId}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Không thể xóa bài hát (mã ${response.statusCode})");
    }
  }

  static Future<void> deletePlaylist(String playlistId, String token) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/delete/$playlistId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Không thể xóa playlist (mã ${response.statusCode})");
    }
  }

  static Future<Playlist> fetchPlaylistDetails(String playlistId, String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$playlistId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Không thể lấy chi tiết playlist (mã ${response.statusCode})");
    }

    final data = jsonDecode(response.body);
    return Playlist.fromJson(data);
  }

  static Future<List<Playlist>> fetchAllPlaylists(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/all'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Không thể lấy danh sách playlist (mã ${response.statusCode})");
    }

    final Map<String, dynamic> jsonData = jsonDecode(response.body);
    final List<dynamic> playlistsJson = jsonData['playlists'];
    return playlistsJson.map((json) => Playlist.fromJson(json)).toList();
  }
}
