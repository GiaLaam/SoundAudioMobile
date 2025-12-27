import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'music_api_service.dart';

class RecentlyPlayedService {
  static final RecentlyPlayedService _instance = RecentlyPlayedService._internal();
  factory RecentlyPlayedService() => _instance;
  RecentlyPlayedService._internal();

  static const String _storageKey = 'recently_played_songs';
  static const int _maxItems = 50;

  List<Song> _recentlyPlayed = [];
  List<Song> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);

  Future<void> init() async {
    await _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _recentlyPlayed = jsonList.map((item) => Song.fromJson(item)).toList();
      }
    } catch (e) {
      _recentlyPlayed = [];
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _recentlyPlayed.map((song) => song.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
    } catch (e) {
      // ignore
    }
  }

  Future<void> addSong(Song song) async {
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    if (_recentlyPlayed.length > _maxItems) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, _maxItems);
    }
    await _saveToStorage();
  }

  Future<void> clear() async {
    _recentlyPlayed.clear();
    await _saveToStorage();
  }

  List<Song> getRecent({int limit = 20}) {
    return _recentlyPlayed.take(limit).toList();
  }
}
