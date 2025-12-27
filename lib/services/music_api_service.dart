import 'dart:convert';
import 'package:http/http.dart' as http;

class Song {
  final String? id;
  final String? name;
  final String? fileName;
  final String? filePath;
  final String? imageUrl;
  final String? duration; // raw time string from backend, e.g. "28:51"

  Duration? get durationFallback {
    if (duration == null) return null;
    try {
      final parts = duration!.split(':').map((s) => int.tryParse(s)).toList();
      if (parts.isEmpty) return null;
      if (parts.length == 2) {
        final minutes = parts[0] ?? 0;
        final seconds = parts[1] ?? 0;
        return Duration(minutes: minutes, seconds: seconds);
      } else if (parts.length == 3) {
        final hours = parts[0] ?? 0;
        final minutes = parts[1] ?? 0;
        final seconds = parts[2] ?? 0;
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }
    } catch (_) {}
    return null;
  }

  Song({
    this.id,
    this.name,
    this.fileName,
    this.filePath,
    this.imageUrl,
    this.duration,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? json['_id']?['\$oid'],
      name: json['nameSong'] ?? json['NameSong'] ?? json['name'],
      fileName: json['fileName'] ?? json['FileName'],
      filePath: json['filePath'] ?? json['FilePath'],
      imageUrl: json['imageUrl'] ?? json['ImageUrl'],
      duration: json['duration'] ?? json['Duration'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fileName': fileName,
      'filePath': filePath,
      'imageUrl': imageUrl,
      'duration': duration,
    };
  }
}

class ApiService {
  static const baseUrl = "https://difficulties-filled-did-announce.trycloudflare.com/api/music";

  static Future<List<Song>> fetchSongs() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((e) => Song.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load songs');
    }
  }

  /// Lấy thông tin chi tiết một bài hát theo ID
  static Future<Song?> fetchSongById(String songId) async {
    try {
      print('🔄 Đang tải thông tin bài hát: $songId');
      final url = '$baseUrl/$songId';
      print('📡 URL: $url');
      
      final response = await http.get(Uri.parse(url));
      
      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Đã tải thông tin bài hát: ${data['nameSong'] ?? data['NameSong']}');
        return Song.fromJson(data);
      } else if (response.statusCode == 404) {
        print('⚠️ Không tìm thấy bài hát với ID: $songId');
        print('⚠️ Có thể bài hát đã bị xóa hoặc musicId không đúng');
        return null;
      } else {
        print('❌ Lỗi: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Lỗi khi tải bài hát: $e');
      return null;
    }
  }

  static Future<String> fetchLyricBySongId(String songId) async {
    final response = await http.get(
      Uri.parse('https://difficulties-filled-did-announce.trycloudflare.com/api/lyric/by-song/$songId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'] ?? 'Chưa có lời bài hát';
    } else if (response.statusCode == 404) {
      return "Chưa có lời bài hát";
    } else {
      throw Exception ('Không thể tải lời bài hát (mã ${response.statusCode})');
    }
  }
}
