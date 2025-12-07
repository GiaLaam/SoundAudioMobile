import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'music_api_service.dart';
import 'signalr_service.dart';

/// AudioPlayerService hoàn chỉnh
/// - playlist via ConcatenatingAudioSource
/// - playSong, setPlaylist, next, previous
/// - shuffle / repeat
/// - streams: currentSongStream, isPlayingStream, position/duration streams nếu cần
class AudioPlayerService {
  // singleton
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  // internal player
  final AudioPlayer _player = AudioPlayer();
  
  // SignalR service
  final SignalRService _signalR = SignalRService();

  // playlist dữ liệu (models)
  List<Song> _songs = [];

  // audio source (urls)
  ConcatenatingAudioSource? _audioSource;

  // trạng thái
  int _currentIndex = 0;

  // streams để UI lắng nghe
  final BehaviorSubject<Song?> currentSongStream = BehaviorSubject.seeded(null);
  final BehaviorSubject<bool> isPlayingStream = BehaviorSubject.seeded(false);

  // Khởi tạo (gọi một lần khi app start)
  Future<void> init() async {
    await _player.setVolume(1.0);

    // Khởi tạo SignalR
    await _signalR.initialize();
    
    // Lắng nghe lệnh dừng từ thiết bị khác
    _signalR.stopPlaybackStream.listen((deviceId) {
      print('🛑 Received stop command from device: $deviceId');
      pause();
    });

    // 🆕 Lắng nghe khi thiết bị khác BÁT ĐẦU PHÁT nhạc
    _signalR.playbackInfoStream.listen((info) {
      final songInfo = info['songInfo'] as Map<String, dynamic>?;
      final songName = songInfo?['songName'] ?? 'Unknown';
      final deviceName = songInfo?['device'] ?? 'Another device';
      
      print('🎵 Another device started playing:');
      print('   Device: $deviceName');
      print('   Song: $songName');
      print('   → Auto-pausing this device');
      
      // Tự động dừng phát trên thiết bị này
      pause();
    });

    // cập nhật playing stream
    _player.playingStream.listen((playing) {
      isPlayingStream.add(playing);
      print('playingStream -> playing=$playing');
      // ❌ KHÔNG gọi notifyPlaybackStarted() ở đây
      // Việc thông báo đã được xử lý trong playSong() và play() với đầy đủ thông tin bài hát
    });

    // khi currentIndex thay đổi
    _player.currentIndexStream.listen((idx) {
      print('currentIndexStream -> idx=$idx');
      if (idx != null && _songs.isNotEmpty && idx >= 0 && idx < _songs.length) {
        _currentIndex = idx;
        currentSongStream.add(_songs[_currentIndex]);
        print('currentSong -> ${_songs[_currentIndex].name} (index=$_currentIndex)');
      } else {
        currentSongStream.add(null);
        print('currentSong -> null');
      }
    });

    // logging position/duration/playerState/loop/shuffle
    _player.positionStream.listen((p) {
      print('positionStream -> $p');
    });

    _player.durationStream.listen((d) {
      print('durationStream -> $d');
    });

    _player.playerStateStream.listen((state) {
      print('playerStateStream -> playing=${state.playing}, processingState=${state.processingState}');
    });

    _player.shuffleModeEnabledStream.listen((enabled) {
      print('shuffleModeEnabledStream -> $enabled');
    });

    _player.loopModeStream.listen((mode) {
      print('loopModeStream -> $mode');
    });

    // Log sequenceState changes (currentSource tag and index)
    _player.sequenceStateStream.listen((seq) {
      try {
        final idx = seq?.currentIndex;
        final tag = seq?.currentSource?.tag;
        print('sequenceStateStream -> currentIndex=$idx, tag=$tag');
      } catch (e) {
        print('sequenceStateStream -> error reading seq: $e');
      }
    });

    // xử lý khi bài kết thúc
    _player.processingStateStream.listen((state) async {
      print('processingStateStream -> $state');
      if (state == ProcessingState.completed) {
        if (_player.hasNext) {
          await next();
        } else if (_player.loopMode == LoopMode.all) {
          // Nếu đang ở chế độ repeat all và là bài cuối, quay lại bài đầu
          await _player.seek(Duration.zero, index: 0);
          await _player.play();
        }
      }
    });

    // Khởi tạo chế độ loop mặc định
    await _player.setLoopMode(LoopMode.off);
  }

  // ---------- Public API ----------

  /// Set playlist (dựa trên List<Song> model).
  /// This builds a ConcatenatingAudioSource from song.filePath.
  Future<void> setPlaylist(List<Song> songs, {int startIndex = 0}) async {
    _songs = List<Song>.from(songs);

    print('AudioPlayerService.setPlaylist called with ${_songs.length} songs, startIndex=$startIndex');

    // build audio source list
    final children = _songs.map((s) {
      final url = _buildUrlFromSong(s);
      // normalize image url for tag
      final rawImage = s.imageUrl ?? '';
      String imageFull;
      if (rawImage.startsWith('http')) {
        imageFull = rawImage;
      } else if (rawImage.startsWith('/')) {
        imageFull = 'https://willing-baltimore-brunette-william.trycloudflare.com$rawImage';
      } else if (rawImage.isEmpty) {
        imageFull = '';
      } else {
        imageFull = 'https://willing-baltimore-brunette-william.trycloudflare.com/$rawImage';
      }

      print(' - song id=${s.id}, name=${s.name}, url=$url, image=$imageFull');
      return AudioSource.uri(Uri.parse(url),
          tag: {
            'id': s.id,
            'name': s.name ?? s.fileName ?? '',
            'imageUrl': imageFull,
            'filePath': s.filePath ?? ''
          });
    }).toList();

    _audioSource = ConcatenatingAudioSource(children: children);

    try {
      print('Calling _player.setAudioSource...');
      await _player.setAudioSource(_audioSource!, initialIndex: startIndex);
      _currentIndex = startIndex;
      print('setAudioSource succeeded. processingState=${_player.processingState}, duration=${_player.duration}');
      if (_songs.isNotEmpty) currentSongStream.add(_songs[_currentIndex]);
      if (_player.duration == null) {
        print('Warning: player.duration is null after setAudioSource — server may not provide metadata or file unreachable');
      }
    } catch (e, st) {
      // lỗi khi set audio source
      print('AudioPlayerService.setPlaylist error: $e');
      print(st);
    }
  }

  /// Play a Song (ensure playlist is set)
  Future<void> playSong(Song song, {List<Song>? songsAsPlaylist}) async {
    try {
      print('AudioPlayerService.playSong called for song id=${song.id}, name=${song.name}');

      // Thông báo cho server trước khi phát - GỬI KÈM THÔNG TIN BÀI HÁT
      await _signalR.notifyPlaybackStarted(
        songId: song.id.toString(),
        songName: song.name ?? song.fileName ?? 'Unknown',
        artistName: '', // Song model không có artistName
        imageUrl: song.imageUrl ?? '',
      );

      // If a new playlist is provided
      if (songsAsPlaylist != null && songsAsPlaylist.isNotEmpty) {
        // find index in provided playlist
        final idxInProvided = songsAsPlaylist.indexWhere((s) => s.id == song.id);
        if (idxInProvided != -1) {
          print('playSong: setting new playlist with startIndex=$idxInProvided');
          await setPlaylist(songsAsPlaylist, startIndex: idxInProvided);
          // after setAudioSource with initialIndex, just play
          await _player.play();
          print('playSong: started playback after setPlaylist (initialIndex)');
          return;
        } else {
          // provided playlist doesn't contain the song, fallback to set full playlist then seek
          print('playSong: provided playlist does not contain song, setting playlist normally');
          await setPlaylist(songsAsPlaylist);
        }
      }

      // If still no playlist, set single-song playlist
      if (_songs.isEmpty) {
        print('playSong: no existing playlist, setting single-song playlist');
        await setPlaylist([song]);
        await _player.play();
        return;
      }

      // Find index in current playlist
      final idx = _songs.indexWhere((s) => s.id == song.id);
      print('playSong: found index=$idx in current playlist');
      if (idx == -1) {
        // not found: set single-song playlist
        await setPlaylist([song]);
        await _player.play();
        return;
      }

      // seek then play
      await _player.seek(Duration.zero, index: idx);
      print('playSong: seeked to index $idx, processingState=${_player.processingState}, position=${_player.position}');
      await _player.play();
      print('playSong: play invoked, player.playing=${_player.playing}');
    } catch (e, st) {
      print('AudioPlayerService.playSong error: $e');
      print(st);
      rethrow;
    }
  }

  Future<void> play() async {
    try {
      // Thông báo cho server trước khi phát - GỬI THÔNG TIN BÀI HIỆN TẠI
      final currentSong = currentSongStream.valueOrNull;
      if (currentSong != null) {
        await _signalR.notifyPlaybackStarted(
          songId: currentSong.id.toString(),
          songName: currentSong.name ?? currentSong.fileName ?? 'Unknown',
          artistName: '', // Song model không có artistName
          imageUrl: currentSong.imageUrl ?? '',
        );
      }
      
      // Always attempt to play — avoid guarding on processingState which may be stale
      print('AudioPlayerService.play called. processingState=${_player.processingState}, playing=${_player.playing}');
      await _player.play();
    } catch (e) {
      print('AudioPlayerService.play error: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      print('AudioPlayerService.pause called.');
      await _player.pause();
    } catch (e) {
      print('AudioPlayerService.pause error: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    currentSongStream.add(null);
  }

  Future<void> next() async {
    if (_audioSource == null || _songs.isEmpty) return;
    try {
      print('AudioPlayerService.next called. hasNext=${_player.hasNext}, loopMode=${_player.loopMode}');
      if (_player.hasNext) {
        await _player.seekToNext();
        await _player.play();
      } else if (_player.loopMode == LoopMode.all && _songs.isNotEmpty) {
        // Trong chế độ repeat all, quay lại bài đầu
        await _player.seek(Duration.zero, index: 0);
        await _player.play();
      }
    } catch (e) {
      print('AudioPlayerService.next error: $e');
      rethrow;
    }
  }

  Future<void> previous() async {
    if (_audioSource == null || _songs.isEmpty) return;
    try {
      print('AudioPlayerService.previous called. hasPrevious=${_player.hasPrevious}, position=${_player.position}');
      // Nếu đang phát được hơn 3 giây, quay về đầu bài hiện tại
      if (_player.position.inSeconds > 3) {
        await _player.seek(Duration.zero);
        await _player.play();
        return;
      }

      if (_player.hasPrevious) {
        await _player.seekToPrevious();
        await _player.play();
      } else if (_player.loopMode == LoopMode.all && _songs.isNotEmpty) {
        // Trong chế độ repeat all, chuyển đến bài cuối
        final lastIndex = _songs.length - 1;
        await _player.seek(Duration.zero, index: lastIndex);
        await _player.play();
      }
    } catch (e) {
      print('AudioPlayerService.previous error: $e');
      rethrow;
    }
  }

  /// Toggle shuffle (true/false)
  Future<void> toggleShuffle() async {
    final newShuffle = !_player.shuffleModeEnabled;
    await _player.setShuffleModeEnabled(newShuffle);
  }

  /// Toggle repeat modes: off -> all -> one -> off
  void toggleRepeatMode() {
    final current = _player.loopMode;
    LoopMode nextMode;
    if (current == LoopMode.off) nextMode = LoopMode.all;
    else if (current == LoopMode.all) nextMode = LoopMode.one;
    else nextMode = LoopMode.off;
    _player.setLoopMode(nextMode);
  }

  // ---------- Helpers / getters ----------

  AudioPlayer get player => _player;

  Song? get currentSong => currentSongStream.valueOrNull;

  bool get isPlaying => _player.playing;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  /// Build full url from Song (adjust base if needed)
  String _buildUrlFromSong(Song s) {
    // song.filePath should already be like "/api/music/xxx.mp3"
    final base = 'https://willing-baltimore-brunette-william.trycloudflare.com';
    final path = s.filePath ?? s.fileName ?? '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return base + path;
    return '$base/$path';
  }

  Future<void> dispose() async {
    await _player.dispose();
    await currentSongStream.close();
    await isPlayingStream.close();
    _signalR.dispose();
  }
}
