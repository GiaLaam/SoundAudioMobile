import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioManager extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  String? _currentSongName;
  String? _currentSongUrl;
  bool _isPlaying = false;

  String? get currentSongName => _currentSongName;
  bool get isPlaying => _isPlaying;

  Future<void> playSong(String url, String name) async {
    try {
      if (_currentSongUrl != url) {
        await _player.setUrl(url);
        _currentSongUrl = url;
        _currentSongName = name;
      }
      await _player.play();
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Lỗi phát nhạc: $e");
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    await _player.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
