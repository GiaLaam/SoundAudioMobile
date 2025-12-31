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
    print('📦 Parsing Playlist from JSON...');
    print('   - id: ${json['id']}');
    print('   - name: ${json['name']}');
    print('   - ownerId: ${json['ownerId']}');
    print('   - userId: ${json['userId']}');
    print('   - musicIds: ${json['musicIds']}');
    print('   - songs: ${json['songs']}');
    
    final allSongsJson = json['songs'] as List<dynamic>? ?? [];
    print('   - Số lượng bài hát: ${allSongsJson.length}');
    
    final songList = allSongsJson.map((s) {
      try {
        return Song.fromJson(s);
      } catch (e) {
        print('   ❌ Lỗi parse song: $e');
        print('   Song data: $s');
        rethrow;
      }
    }).toList();
    
    // Backend dùng "ownerId" thay vì "userId"
    final userId = json['userId'] ?? json['ownerId'] ?? '';
    
    return Playlist(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      userId: userId,
      songs: songList,
      musicIds: (json['musicIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class PlaylistService {
  static const String baseUrl = 'https://civil-specialist-usual-main.trycloudflare.com/api/playlist';
  final AuthService _authService = AuthService();

  /// Lấy danh sách playlist của user
  Future<List<Playlist>> getUserPlaylists() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        print('⚠️ User chưa đăng nhập');
        return [];
      }

      print('🔄 Đang tải playlist cho user...');
      // Sử dụng endpoint /all thay vì /user-playlists
      final response = await http.get(
        Uri.parse('$baseUrl/all'),
        headers: {
          'Authorization': 'Bearer ${user.token}',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        
        // Xử lý trường hợp response có cấu trúc {"success": true, "data": [...]}
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          final dataContent = data['data'];
          
          if (dataContent is List) {
            print('✅ Tìm thấy ${dataContent.length} playlist trong data array');
            return dataContent.map((json) => Playlist.fromJson(json)).toList();
          }
        }
        
        // Xử lý trường hợp response là List trực tiếp
        if (data is List) {
          print('✅ Tìm thấy ${data.length} playlist');
          return data.map((json) => Playlist.fromJson(json)).toList();
        }
        
        // Xử lý trường hợp response là Map với key 'playlists'
        if (data is Map<String, dynamic>) {
          if (data.containsKey('playlists')) {
            final List<dynamic>? playlistsJson = data['playlists'] as List<dynamic>?;
            if (playlistsJson != null) {
              print('✅ Tìm thấy ${playlistsJson.length} playlist trong Map');
              return playlistsJson.map((json) => Playlist.fromJson(json)).toList();
            }
          }
          // Có thể data chính là một playlist object
          print('✅ Tìm thấy 1 playlist object');
          return [Playlist.fromJson(data)];
        }
        
        print('⚠️ Không tìm thấy playlist nào');
        return [];
      } else if (response.statusCode == 401) {
        print('❌ Token không hợp lệ hoặc hết hạn');
        throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại');
      } else if (response.statusCode == 404) {
        print('⚠️ Endpoint không tồn tại');
        return [];
      }
      
      print('❌ Lỗi server: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ Get playlists error: $e');
      rethrow; // Ném lại exception để UI có thể xử lý
    }
  }

  /// Thêm bài hát vào playlist
  static Future<Playlist> createPlaylist(String name, String token, {String? songId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        if (songId != null && songId.isNotEmpty) 'songId': songId, // chỉ gửi nếu có
      }),
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

  // Đổi tên playlist
  static Future<void> renamePlaylist(String playlistId, String newName, String token) async {
    final response = await http.put(
      Uri.parse('$baseUrl/rename'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'playlistId': playlistId,'newName': newName}),
    );

    if (response.statusCode != 200) {
      throw Exception("Không thể đổi tên playlist (mã ${response.statusCode})");
    }
  }

  // Xóa playlist
  static Future<void> deletePlaylist(String playlistId, String token) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/delete/$playlistId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Không thể xóa playlist (mã ${response.statusCode})");
    }
  }


  static Future<Playlist> fetchPlaylistDetails(String playlistId, String token) async {
    print('🔄 Đang tải chi tiết playlist: $playlistId');
    
    final response = await http.get(
      Uri.parse('$baseUrl/$playlistId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('📡 Response status: ${response.statusCode}');
    print('📡 Response body: ${response.body}');

    if (response.statusCode == 404) {
      print('⚠️ Endpoint không tồn tại, thử lấy từ danh sách playlist');
      // Fallback: Lấy từ danh sách tất cả playlist
      final allPlaylists = await fetchAllPlaylists(token);
      final playlist = allPlaylists.firstWhere(
        (p) => p.id == playlistId,
        orElse: () => throw Exception('Không tìm thấy playlist'),
      );
      
      // Nếu playlist có musicIds nhưng không có songs, tải thông tin bài hát
      if (playlist.songs.isEmpty && playlist.musicIds.isNotEmpty) {
        print('🔄 Đang tải thông tin ${playlist.musicIds.length} bài hát...');
        final List<Song> songs = [];
        
        for (String musicId in playlist.musicIds) {
          try {
            final song = await ApiService.fetchSongById(musicId);
            if (song != null) {
              songs.add(song);
              print('   ✅ Đã tải: ${song.name}');
            }
          } catch (e) {
            print('   ❌ Lỗi tải bài hát $musicId: $e');
          }
        }
        
        print('✅ Đã tải ${songs.length}/${playlist.musicIds.length} bài hát');
        
        return Playlist(
          id: playlist.id,
          name: playlist.name,
          userId: playlist.userId,
          songs: songs,
          musicIds: playlist.musicIds,
        );
      }
      
      return playlist;
    }

    if (response.statusCode != 200) {
      throw Exception("Không thể lấy chi tiết playlist (mã ${response.statusCode})");
    }

    final data = jsonDecode(response.body);
    
    // ⭐ Kiểm tra xem response có cấu trúc {"success": true, "playlist": {...}, "songs": [...]}
    if (data is Map<String, dynamic> && data.containsKey('playlist') && data.containsKey('songs')) {
      print('✅ Response có cả playlist và songs array');
      
      final playlistData = data['playlist'] as Map<String, dynamic>;
      final songsData = data['songs'] as List<dynamic>? ?? [];
      
      print('   - Playlist: ${playlistData['name']}');
      print('   - Số bài hát trong songs array: ${songsData.length}');
      
      // Parse songs từ mảng songs bên ngoài
      final List<Song> songs = songsData.map((s) {
        try {
          return Song.fromJson(s);
        } catch (e) {
          print('   ❌ Lỗi parse song: $e');
          return null;
        }
      }).whereType<Song>().toList();
      
      print('✅ Đã parse ${songs.length} bài hát thành công');
      
      return Playlist(
        id: playlistData['id'] ?? '',
        name: playlistData['name'] ?? '',
        userId: playlistData['ownerId'] ?? playlistData['userId'] ?? '',
        songs: songs,
        musicIds: (playlistData['musicIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      );
    }
    
    // Kiểm tra xem data có phải là object với key 'playlist' không (cấu trúc cũ)
    Playlist playlist;
    if (data is Map<String, dynamic> && data.containsKey('playlist')) {
      print('✅ Tìm thấy playlist trong response.playlist');
      playlist = Playlist.fromJson(data['playlist']);
    } else {
      // Nếu không thì data chính là playlist object
      print('✅ Response chính là playlist object');
      playlist = Playlist.fromJson(data);
    }
    
    // ⭐ QUAN TRỌNG: Nếu playlist có musicIds nhưng không có songs, tải thông tin bài hát
    if (playlist.songs.isEmpty && playlist.musicIds.isNotEmpty) {
      print('🔄 Playlist có ${playlist.musicIds.length} musicIds nhưng 0 songs');
      print('🔄 Đang tải thông tin bài hát từ API...');
      final List<Song> songs = [];
      
      for (String musicId in playlist.musicIds) {
        try {
          print('   📡 Đang tải bài hát: $musicId');
          final song = await ApiService.fetchSongById(musicId);
          if (song != null) {
            songs.add(song);
            print('   ✅ Đã tải: ${song.name}');
          } else {
            print('   ⚠️ Bài hát $musicId không tồn tại');
          }
        } catch (e) {
          print('   ❌ Lỗi tải bài hát $musicId: $e');
        }
      }
      
      print('✅ Hoàn thành: Đã tải ${songs.length}/${playlist.musicIds.length} bài hát');
      
      return Playlist(
        id: playlist.id,
        name: playlist.name,
        userId: playlist.userId,
        songs: songs,
        musicIds: playlist.musicIds,
      );
    }
    
    return playlist;
  }

  static Future<List<Playlist>> fetchAllPlaylists(String token) async {
    try {
      print('🔄 Đang tải tất cả playlist...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/all'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 fetchAllPlaylists - Response status: ${response.statusCode}');
      print('📡 fetchAllPlaylists - Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception("Không thể lấy danh sách playlist (mã ${response.statusCode})");
      }

      final dynamic jsonData = jsonDecode(response.body);
      
      // Xử lý trường hợp response có cấu trúc {"success": true, "data": [...]}
      if (jsonData is Map<String, dynamic> && jsonData.containsKey('data')) {
        final dataContent = jsonData['data'];
        
        if (dataContent is List) {
          print('✅ Tìm thấy ${dataContent.length} playlist trong data array');
          return dataContent.map((json) => Playlist.fromJson(json)).toList();
        }
      }
      
      // Xử lý trường hợp response là List trực tiếp
      if (jsonData is List) {
        print('✅ Tìm thấy ${jsonData.length} playlist trong List');
        return jsonData.map((json) => Playlist.fromJson(json)).toList();
      }
      
      // Xử lý trường hợp response là Map với key 'playlists'
      if (jsonData is Map<String, dynamic>) {
        final List<dynamic>? playlistsJson = jsonData['playlists'] as List<dynamic>?;
        if (playlistsJson != null) {
          print('✅ Tìm thấy ${playlistsJson.length} playlist trong Map');
          return playlistsJson.map((json) => Playlist.fromJson(json)).toList();
        }
      }
      
      print('⚠️ Response không phải List hoặc Map với data');
      return [];
    } catch (e) {
      print('❌ Lỗi tải playlist: $e');
      rethrow;
    }
  }
}
