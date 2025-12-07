import 'dart:convert';
import 'package:http/http.dart' as http;
import 'music_api_service.dart';

class Album {
  final String id;
  final String name;
  final String? imageUrl;
  final String? description;
  final int? songCount;
  final List<Song>? songs;

  Album({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
    this.songCount,
    this.songs,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    // Tạo imageUrl từ id của album nếu không có imageUrl trong response
    final albumId = json['id'] ?? '';
    String? imageUrl = json['imageUrl'] ?? json['ImageUrl'];
    
    // Nếu không có imageUrl, tạo URL từ id
    if ((imageUrl == null || imageUrl.isEmpty) && albumId.isNotEmpty) {
      imageUrl = '/api/AlbumApi/$albumId/image';
    }
    
    return Album(
      id: albumId,
      name: json['name'] ?? json['Name'] ?? json['title'] ?? '',
      imageUrl: imageUrl,
      description: json['description'] ?? json['Description'],
      songCount: json['songCount'] ?? json['SongCount'],
      songs: json['songs'] != null 
        ? (json['songs'] as List).map((s) => Song.fromJson(s)).toList()
        : null,
    );
  }
}

class AlbumService {
  static const String baseUrl = 'https://willing-baltimore-brunette-william.trycloudflare.com/api/AlbumApi';

  /// Lấy danh sách tất cả albums
  static Future<List<Album>> fetchAlbums() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        
        // Xử lý response với cấu trúc {"success": true, "data": [...]}
        if (decodedData is Map<String, dynamic>) {
          // Kiểm tra key 'data' trước
          if (decodedData['data'] != null) {
            final List<dynamic> albumsList = decodedData['data'];
            return albumsList.map((album) => Album.fromJson(album)).toList();
          }
          // Nếu không có 'data', thử các key khác
          final List<dynamic>? albumsList = decodedData['albums'] ?? 
                                            decodedData['items'] ??
                                            decodedData['Albums'];
          
          if (albumsList != null) {
            return albumsList.map((album) => Album.fromJson(album)).toList();
          } else {
            // Nếu không tìm thấy key nào, có thể toàn bộ Map là một album duy nhất
            return [Album.fromJson(decodedData)];
          }
        } else if (decodedData is List) {
          // Nếu là List trực tiếp
          return decodedData.map((album) => Album.fromJson(album)).toList();
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception('Failed to load albums (status ${response.statusCode})');
      }
    } catch (e) {
      print('Error fetching albums: $e');
      rethrow;
    }
  }

  /// Lấy chi tiết album theo ID
  static Future<Album> fetchAlbumById(String albumId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$albumId'));

      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        
        // Xử lý response với cấu trúc {"success": true, "data": {...}}
        if (decodedData is Map<String, dynamic>) {
          if (decodedData['data'] != null) {
            return Album.fromJson(decodedData['data']);
          }
          // Nếu không có 'data', parse trực tiếp
          return Album.fromJson(decodedData);
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception('Failed to load album details (status ${response.statusCode})');
      }
    } catch (e) {
      print('Error fetching album details: $e');
      rethrow;
    }
  }

  /// Lấy chi tiết album (endpoint /details) - Sử dụng fetchAlbumById thay vì /details
  static Future<Album> fetchAlbumDetails(String albumId) async {
    // API không có endpoint /details riêng, sử dụng /{id} để lấy thông tin album
    return fetchAlbumById(albumId);
  }

  /// Lấy danh sách bài hát trong album
  static Future<List<Song>> fetchSongsByAlbum(String albumId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$albumId/songs'));

      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        
        // Xử lý response với cấu trúc {"success": true, "data": [...]}
        if (decodedData is Map<String, dynamic>) {
          if (decodedData['data'] != null) {
            final List<dynamic> songsList = decodedData['data'];
            return songsList.map((song) => Song.fromJson(song)).toList();
          }
          // Nếu không có 'data', thử các key khác
          final List<dynamic>? songsList = decodedData['songs'] ?? 
                                           decodedData['items'] ??
                                           decodedData['Songs'];
          
          if (songsList != null) {
            return songsList.map((song) => Song.fromJson(song)).toList();
          } else {
            return [];
          }
        } else if (decodedData is List) {
          return decodedData.map((song) => Song.fromJson(song)).toList();
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception('Failed to load songs in album (status ${response.statusCode})');
      }
    } catch (e) {
      print('Error fetching songs in album: $e');
      rethrow;
    }
  }

  /// Lấy URL ảnh của album
  static String getAlbumImageUrl(String albumId) {
    return '$baseUrl/$albumId/image';
  }

  /// Tạo album mới (POST)
  static Future<Album> createAlbum({
    required String name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          if (description != null) 'description': description,
          if (imageUrl != null) 'imageUrl': imageUrl,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return Album.fromJson(data);
      } else {
        throw Exception('Failed to create album (status ${response.statusCode})');
      }
    } catch (e) {
      print('Error creating album: $e');
      rethrow;
    }
  }

  /// Cập nhật album (PUT)
  static Future<Album> updateAlbum({
    required String albumId,
    required String name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$albumId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          if (description != null) 'description': description,
          if (imageUrl != null) 'imageUrl': imageUrl,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Album.fromJson(data);
      } else {
        throw Exception('Failed to update album (status ${response.statusCode})');
      }
    } catch (e) {
      print('Error updating album: $e');
      rethrow;
    }
  }

  /// Xóa album (DELETE)
  static Future<void> deleteAlbum(String albumId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/$albumId'));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete album (status ${response.statusCode})');
      }
    } catch (e) {
      print('Error deleting album: $e');
      rethrow;
    }
  }
}