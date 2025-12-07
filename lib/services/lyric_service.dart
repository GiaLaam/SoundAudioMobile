import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lyric_line.dart';

class LyricService {
  static const String baseUrl = 'https://willing-baltimore-brunette-william.trycloudflare.com/api/lyric';

  static Future<List<LyricLine>> fetchLyricsBySongId(String songId) async {
    final response = await http.get(Uri.parse('$baseUrl/by-song/$songId'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final content = data['content'] ?? data['Content'] ?? '';
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty);

      return lines.map((line) => LyricLine.fromLrc(line)).toList();
    } else {
      throw Exception('Lỗi tải lời bài hát: ${response.statusCode}');
    }
  }
}
