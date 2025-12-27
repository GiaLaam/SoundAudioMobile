import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'music_api_service.dart';
import 'signalr_service.dart';
import 'recently_played_service.dart';
import 'dart:async';

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

  // Stream để thông báo khi bị dừng do thiết bị khác phát
  final StreamController<Map<String, dynamic>> _devicePlaybackNotificationController = 
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get devicePlaybackNotificationStream => 
      _devicePlaybackNotificationController.stream;

  // Stream để broadcast remote position (cho UI hiển thị khi không phát)
  final BehaviorSubject<Duration?> remotePositionStream = BehaviorSubject.seeded(null);
  final BehaviorSubject<bool> isRemotePlayingStream = BehaviorSubject.seeded(false);
  
  // Timer để gửi sync position
  Timer? _syncTimer;

  // Khởi tạo (gọi một lần khi app start)
  Future<void> init() async {
    await _player.setVolume(1.0);

    // Khởi tạo SignalR
    await _signalR.initialize();
    
    // Lắng nghe lệnh dừng từ thiết bị khác
    _signalR.stopPlaybackStream.listen((data) {
      final deviceId = data['deviceId'] ?? 'unknown';
      final deviceName = data['deviceName'] ?? 'Another device';
      final songName = data['songName'] ?? '';
      
      print('🛑 Received stop command from device: $deviceId ($deviceName)');
      
      // Dừng phát nhạc
      pause();
      
      // Gửi thông báo để UI hiển thị
      _devicePlaybackNotificationController.add({
        'deviceId': deviceId,
        'deviceName': deviceName,
        'songName': songName,
        'message': 'Đang phát trên $deviceName',
      });
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
      
      // Gửi thông báo để UI hiển thị
      _devicePlaybackNotificationController.add({
        'deviceName': deviceName,
        'songName': songName,
        'message': 'Đang phát trên $deviceName',
      });
    });

    // 🆕 Lắng nghe khi được yêu cầu phát nhạc từ thiết bị khác (transfer playback)
    _signalR.startPlaybackRemoteStream.listen((data) async {
      final songId = data['songId'] as String?;
      final positionMs = data['positionMs'] as int? ?? 0;
      final shouldPlay = data['isPlaying'] as bool? ?? true;
      final sourceDevice = data['sourceDevice'] as String? ?? 'Another device';
      final remoteSongName = data['songName'] as String? ?? '';
      final remoteImageUrl = data['imageUrl'] as String? ?? '';
      
      print('🎵 Received StartPlaybackRemote:');
      print('   Song ID: $songId');
      print('   Position: ${positionMs}ms');
      print('   Should play: $shouldPlay');
      print('   From: $sourceDevice');
      print('   SongName: $remoteSongName');
      print('   ImageUrl: $remoteImageUrl');
      
      if (songId != null && songId.isNotEmpty) {
        try {
          Song? song;
          bool foundInCurrentPlaylist = false;
          
          // Kiểm tra xem bài hát có trong playlist hiện tại không
          if (_songs.isNotEmpty) {
            final idx = _songs.indexWhere((s) => s.id == songId);
            if (idx != -1) {
              song = _songs[idx];
              foundInCurrentPlaylist = true;
              print('   Found song in current playlist at index $idx');
              
              // Seek đến bài hát đó trong playlist
              await _player.seek(Duration(milliseconds: positionMs), index: idx);
            }
          }
          
          // Nếu không có trong playlist, fetch tất cả bài hát từ API
          if (song == null) {
            print('   Song not in current playlist, fetching all songs from API...');
            final allSongs = await ApiService.fetchSongs();
            
            // Tìm bài hát trong danh sách
            final idx = allSongs.indexWhere((s) => s.id == songId);
            if (idx != -1) {
              song = allSongs[idx];
              
              // Cập nhật imageUrl từ remote nếu cần
              if (remoteImageUrl.isNotEmpty && (song!.imageUrl == null || song!.imageUrl!.isEmpty)) {
                allSongs[idx] = Song(
                  id: song!.id,
                  name: song!.name,
                  fileName: song!.fileName,
                  filePath: song!.filePath,
                  imageUrl: remoteImageUrl,
                  duration: song!.duration,
                );
                song = allSongs[idx];
              }
              
              // Set playlist với TẤT CẢ bài hát để next/prev hoạt động
              await setPlaylist(allSongs, startIndex: idx);
              
              // Seek đến vị trí trong bài
              if (positionMs > 0) {
                await _player.seek(Duration(milliseconds: positionMs));
              }
              
              print('   ✅ Set playlist with ${allSongs.length} songs, starting at index $idx');
            } else {
              // Không tìm thấy, phát bài đầu tiên
              print('   ⚠️ Song not found in API, playing first song');
              song = allSongs.first;
              await setPlaylist(allSongs);
            }
          }
          
          // Phát hoặc dừng tùy theo yêu cầu
          if (shouldPlay) {
            await _player.play();
            // Thông báo server rằng thiết bị này đang phát
            await _signalR.notifyPlaybackStarted(
              songId: song.id,
              songName: song.name ?? remoteSongName,
              imageUrl: song.imageUrl ?? remoteImageUrl,
            );
          } else {
            await _player.pause();
          }
          
          print('✅ Started playing from remote request (foundInPlaylist: $foundInCurrentPlaylist)');
        } catch (e) {
          print('❌ Error starting playback from remote: $e');
        }
      }
    });

    // Lắng nghe đồng bộ vị trí từ thiết bị khác
    _signalR.positionSyncStream.listen((data) {
      final positionMs = data['positionMs'] as int? ?? 0;
      final isPlaying = data['isPlaying'] as bool? ?? false;
      
      // Chỉ cập nhật nếu thiết bị này KHÔNG đang phát
      if (!_player.playing) {
        remotePositionStream.add(Duration(milliseconds: positionMs));
        isRemotePlayingStream.add(isPlaying);
      }
    });

    // cập nhật playing stream
    _player.playingStream.listen((playing) {
      isPlayingStream.add(playing);
      print('playingStream -> playing=$playing');
      
      // Bắt đầu/dừng gửi sync position
      if (playing) {
        _startSyncTimer();
        // Reset remote position khi bắt đầu phát
        remotePositionStream.add(null);
        isRemotePlayingStream.add(false);
      } else {
        _stopSyncTimer();
      }
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
        imageFull = 'https://difficulties-filled-did-announce.trycloudflare.com$rawImage';
      } else if (rawImage.isEmpty) {
        imageFull = '';
      } else {
        imageFull = 'https://difficulties-filled-did-announce.trycloudflare.com/$rawImage';
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

      // Thêm vào lịch sử nghe gần đây
      await RecentlyPlayedService().addSong(song);

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
      // Nếu có remote position và không đang phát, seek đến đó trước
      final remotePos = remotePositionStream.valueOrNull;
      if (remotePos != null && !_player.playing) {
        print('AudioPlayerService.play: Seeking to remote position ${remotePos.inSeconds}s');
        await _player.seek(remotePos);
        remotePositionStream.add(null); // Reset sau khi seek
      }
      
      // Thông báo cho server trước khi phát - GỬI THÔNG TIN BÀI HIỆN TẠI
      final currentSong = currentSongStream.valueOrNull;
      if (currentSong != null) {
        print('🎵 play(): Notifying server about playback start');
        print('   Song: ${currentSong.name}');
        await _signalR.notifyPlaybackStarted(
          songId: currentSong.id.toString(),
          songName: currentSong.name ?? currentSong.fileName ?? 'Unknown',
          artistName: '', // Song model không có artistName
          imageUrl: currentSong.imageUrl ?? '',
        );
        print('   ✅ Server notified');
      } else {
        print('⚠️ play(): No current song, cannot notify server');
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
    final base = 'https://difficulties-filled-did-announce.trycloudflare.com';
    final path = s.filePath ?? s.fileName ?? '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return base + path;
    return '$base/$path';
  }

  // Bắt đầu gửi sync position mỗi 2 giây
  void _startSyncTimer() {
    _stopSyncTimer();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final currentSong = currentSongStream.valueOrNull;
      if (currentSong != null && _player.playing) {
        _signalR.syncPlaybackPosition(
          currentSong.id ?? '',
          _player.position.inMilliseconds,
          true,
        );
      }
    });
  }

  void _stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> dispose() async {
    _stopSyncTimer();
    await _player.dispose();
    await currentSongStream.close();
    await isPlayingStream.close();
    await remotePositionStream.close();
    await isRemotePlayingStream.close();
    await _devicePlaybackNotificationController.close();
    _signalR.dispose();
  }
}
