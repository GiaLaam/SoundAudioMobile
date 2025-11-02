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
      name: json['nameSong'] ?? json['NameSong'],
      fileName: json['fileName'] ?? json['FileName'],
      filePath: json['filePath'] ?? json['FilePath'],
      imageUrl: json['imageUrl'] ?? json['ImageUrl'],
      duration: json['duration'] ?? json['Duration'],
    );
  }
}

class ApiService {
  static const baseUrl = "http://192.168.1.7:5289/api/music"; // chỉnh theo IP nếu test trên iPhone

  static Future<List<Song>> fetchSongs() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((e) => Song.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load songs');
    }
  }
}
