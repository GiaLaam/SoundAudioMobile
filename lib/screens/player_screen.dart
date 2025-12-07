import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/music_api_service.dart';
import 'package:rxdart/rxdart.dart';
import '../services/audio_player_service.dart';
import '../models/lyric_line.dart';
import '../widgets/devices_dialog.dart';
import '../services/signalr_service.dart';

class PlayerScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Song currentSong;
  final bool isPlaying;
  final VoidCallback onTogglePlay;

  const PlayerScreen({
    super.key,
    required this.audioPlayer,
    required this.currentSong,
    required this.isPlaying,
    required this.onTogglePlay,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<LyricLine> _lyricLines = [];
  bool _isLoadingLyric = true;
  double _dragOffset = 0;
  int _currentLyricIndex = -1;
  final ScrollController _lyricScrollController = ScrollController(); // Thêm scroll controller
  bool _autoScroll = true; // Flag để kiểm soát auto-scroll

  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration?, bool, PositionData>(
        widget.audioPlayer.positionStream,
        widget.audioPlayer.durationStream,
        widget.audioPlayer.playingStream,
        (position, duration, isPlaying) {
          Duration finalDuration = Duration.zero;
          if (duration != null && duration.inMilliseconds > 0) {
            finalDuration = duration;
          } else {
            finalDuration = AudioPlayerService().currentSong?.durationFallback ?? Duration.zero;
          }

          return PositionData(
            position: position,
            duration: finalDuration,
            isPlaying: isPlaying,
          );
        },
      ).distinct();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this
    );
    
    // Đảm bảo player được khởi tạo đúng
    widget.audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {}); 
        final currentSequence = widget.audioPlayer.sequenceState?.currentSource?.tag;
        if (currentSequence is Map && currentSequence['id'] != null) {
          final newSongId = currentSequence['id'] as String;
          _reloadLyricIfChanged(newSongId);
        } else {
          _loadLyric();
        }
      }
    });

    // Lắng nghe thay đổi position để cập nhật lyric
    widget.audioPlayer.positionStream.listen((position) {
      if (mounted && _lyricLines.isNotEmpty) {
        _updateCurrentLyric(position);
      }
    });

    // Force re-render khi sequence hoặc currentIndex thay đổi
    widget.audioPlayer.sequenceStateStream.listen((seq) {
      if (mounted) {
        // debug print to console
        try {
          final idx = seq?.currentIndex;
          final tag = seq?.currentSource?.tag;
          debugPrint('PlayerScreen.sequenceState -> idx=$idx, tag=$tag');
        } catch (_) {}
        setState(() {});
      }
    });

    widget.audioPlayer.currentIndexStream.listen((idx) {
      if (mounted) {
        debugPrint('PlayerScreen.currentIndexStream -> idx=$idx');
        setState(() {});
      }
    });

    _loadLyric();
  }

  // Thêm method để cập nhật lyric hiện tại dựa trên position
  void _updateCurrentLyric(Duration position) {
    if (_lyricLines.isEmpty) return;
    
    int newIndex = -1;
    
    // Tìm dòng cuối cùng có thời gian <= position hiện tại
    for (int i = 0; i < _lyricLines.length; i++) {
      if (position >= _lyricLines[i].time) {
        newIndex = i;
      } else {
        break;
      }
    }
    
    // Debug: In ra console để kiểm tra
    if (newIndex >= 0 && newIndex < _lyricLines.length) {
      debugPrint('Current position: ${position.inSeconds}s, Lyric index: $newIndex, Text: ${_lyricLines[newIndex].text}');
    }
    
    if (newIndex != _currentLyricIndex) {
      setState(() {
        _currentLyricIndex = newIndex;
      });
      
      // Auto scroll đến dòng hiện tại
      if (_autoScroll && _lyricScrollController.hasClients && newIndex >= 0) {
        _scrollToCurrentLyric(newIndex);
      }
    }
  }

  List<LyricLine> parseLyric(String rawLyric) {
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\](.*)');
    final lines = <LyricLine>[];

    for (var line in rawLyric.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final hundredths = int.parse(match.group(3)!);
        final text = match.group(4)!.trim();
        
        if (text.isNotEmpty) { // Chỉ thêm dòng có text
          final time = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: hundredths * 10,
          );
          lines.add(LyricLine(time: time, text: text));
        }
      }
    }
    return lines;
  }

  Future<void> _loadLyric([String? songId]) async {
    setState(() => _isLoadingLyric = true);
    try {
      final idToUse = songId ?? widget.currentSong.id ?? _lastLoadedSongId ?? '';
      if (idToUse.isEmpty) throw Exception('Song ID missing');

      final lyric = await ApiService.fetchLyricBySongId(idToUse);
      final parsedLines = parseLyric(lyric);
      
      setState(() {
        _lyricLines = parsedLines;
        _currentLyricIndex = -1;
        _isLoadingLyric = false;
      });
    } catch (e) {
      setState(() {
        _lyricLines = [LyricLine(time: Duration.zero, text: "Chưa có lời bài hát")];
        _isLoadingLyric = false;
      });
    }
  }

  String? _lastLoadedSongId;

  Future<void> _reloadLyricIfChanged(String newSongId) async {
    if (_lastLoadedSongId == newSongId) return;
    _lastLoadedSongId = newSongId;

    setState(() {
      _lyricLines = [];
      _currentLyricIndex = -1;
      _isLoadingLyric = true;
    });

    await _loadLyric(newSongId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _lyricScrollController.dispose(); // Dispose scroll controller
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.primaryDelta!;
      if (_dragOffset < 0) _dragOffset = 0;
      _controller.value = (_dragOffset / 200).clamp(0.0, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragOffset > 100) {
      _controller.forward().then((_) {
        Navigator.pop(context);
      });
    } else {
      _controller.reverse();
      setState(() => _dragOffset = 0);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Method để scroll mượt mà đến dòng hiện tại
  void _scrollToCurrentLyric(int index) {
    if (!_lyricScrollController.hasClients) return;
    
    // Đợi một chút để đảm bảo layout đã hoàn tất
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_lyricScrollController.hasClients) return;
      
      // Tính toán vị trí scroll để dòng hiện tại ở vị trí thích hợp
      // Mỗi item có: padding vertical 12*2=24, margin vertical 6*2=12, text ~22 = ~58px
      final double itemHeight = 58.0; 
      final double containerHeight = 400.0;
      
      // Scroll để dòng hiện tại ở vị trí 1/4 từ trên xuống
      final double targetOffset = (index * itemHeight) - (containerHeight * 0.25);
      
      final double clampedOffset = targetOffset.clamp(
        0.0, 
        _lyricScrollController.position.maxScrollExtent
      );
      
      // Scroll mượt mà
      _lyricScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: StreamBuilder<PositionData>(
        stream: _positionDataStream,
        builder: (context, snapshot) {
          final positionData = snapshot.data ??
              PositionData(
                position: Duration.zero,
                duration: Duration.zero,
                isPlaying: false,
              );

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _dragOffset),
                child: GestureDetector(
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          HSLColor.fromAHSL(1, 200, 0.8, 0.3).toColor(),
                          Colors.black,
                        ],
                        stops: const [0.0, 0.7],
                      ),
                    ),
                    child: Scaffold(
                      backgroundColor: Colors.transparent,
                      appBar: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                          onPressed: () => Navigator.pop(context),
                        ),
                        title: StreamBuilder<SequenceState?>(
                          stream: widget.audioPlayer.sequenceStateStream,
                          builder: (context, seqSnap) {
                            // Keep only the fixed heading in the AppBar; do not show song name or filepath here.
                            return const Text(
                              'ĐỀ XUẤT CHO BẠN',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                letterSpacing: 1,
                              ),
                            );
                          },
                        ),
                        centerTitle: true,
                      ),
                      body: SizedBox(
                        height: size.height - MediaQuery.of(context).padding.top,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 30),
                              // Album Art
                              StreamBuilder<SequenceState?>(
                                stream: widget.audioPlayer.sequenceStateStream,
                                builder: (context, seqSnap) {
                                  final seq = seqSnap.data;
                                  final idx = seq?.currentIndex ?? widget.audioPlayer.currentIndex;
                                  final tag = seq?.currentSource?.tag as Map?;
                                  debugPrint('PlayerScreen.album seq -> idx=$idx, tag=$tag');

                                  final displayName = (tag is Map && tag['name'] != null)
                                      ? tag['name'] as String
                                      : (AudioPlayerService().currentSong?.name ?? widget.currentSong.name ?? 'Unknown');
                                  final rawImage = (tag is Map && tag['imageUrl'] != null)
                                      ? tag['imageUrl'] as String
                                      : (AudioPlayerService().currentSong?.imageUrl ?? widget.currentSong.imageUrl ?? '');
                                  final imageUrl = rawImage.startsWith('http') ? rawImage : (rawImage.isNotEmpty ? 'https://willing-baltimore-brunette-william.trycloudflare.com$rawImage' : rawImage);

                                  return Column(
                                    children: [
                                      Container(
                                        width: size.width * 0.75,
                                        height: size.width * 0.75,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 15,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(
                                              Icons.music_note,
                                              color: Colors.white54,
                                              size: 80,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Song Info
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            // file path / filename removed intentionally
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              // Progress Bar with Time
                              Column(
                                children: [
                                  SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6,
                                      ),
                                      overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 12,
                                      ),
                                      activeTrackColor: Colors.white,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: Colors.white,
                                      overlayColor: Colors.white24,
                                    ),
                                    child: Slider(
                                      min: 0,
                                      max: positionData.duration.inMilliseconds.toDouble() == 0
                                          ? 1
                                          : positionData.duration.inMilliseconds.toDouble(),
                                      value: positionData.duration.inMilliseconds > 0
                                          ? positionData.position.inMilliseconds.toDouble().clamp(
                                              0,
                                              positionData.duration.inMilliseconds.toDouble(),
                                            )
                                          : 0,
                                      onChanged: positionData.duration.inMilliseconds > 0
                                          ? (value) {
                                              widget.audioPlayer.seek(
                                                Duration(milliseconds: value.round()),
                                              );
                                            }
                                          : null,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(positionData.position),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          // show fallback duration if player duration unknown
                                          (positionData.duration.inMilliseconds > 0)
                                              ? _formatDuration(positionData.duration)
                                              : '--:--',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Controls
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  StreamBuilder<bool>(
                                    stream: widget.audioPlayer.shuffleModeEnabledStream,
                                    builder: (context, snapshot) {
                                      final isShuffleEnabled = snapshot.data ?? false;
                                      return IconButton(
                                        icon: Icon(
                                          Icons.shuffle,
                                          color: isShuffleEnabled
                                              ? Colors.green
                                              : Colors.white54,
                                        ),
                                        onPressed: () {
                                          widget.audioPlayer.setShuffleModeEnabled(!isShuffleEnabled);
                                        },
                                      );
                                    },
                                  ),
                                  IconButton(
                                    iconSize: 44,
                                    icon: const Icon(Icons.skip_previous),
                                    color: widget.audioPlayer.hasPrevious
                                        ? Colors.white
                                        : Colors.white24,
                                    onPressed: widget.audioPlayer.hasPrevious
                                        ? () => widget.audioPlayer.seekToPrevious()
                                        : null,
                                  ),
                                  GestureDetector(
                                    onTapDown: (_) => _controller.forward(),
                                    onTapUp: (_) async {
                                      _controller.reverse();
                                      // Gọi trực tiếp trên audioPlayer để tránh callback bị capture trạng thái cũ
                                      try {
                                        if (widget.audioPlayer.playing) {
                                          await widget.audioPlayer.pause();
                                        } else {
                                          await widget.audioPlayer.play();
                                        }
                                      } catch (e) {
                                        // ignore
                                      }
                                    },
                                    onTapCancel: () => _controller.reverse(),
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(36),
                                      ),
                                      child: Icon(
                                        positionData.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        size: 44,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    iconSize: 44,
                                    icon: const Icon(Icons.skip_next),
                                    color: widget.audioPlayer.hasNext
                                        ? Colors.white
                                        : Colors.white24,
                                    onPressed: widget.audioPlayer.hasNext
                                        ? () async {
                                            try {
                                              await widget.audioPlayer.seekToNext();
                                              await widget.audioPlayer.play();
                                            } catch (e) {}
                                          }
                                        : null,
                                  ),
                                  StreamBuilder<LoopMode>(
                                    stream: widget.audioPlayer.loopModeStream,
                                    builder: (context, snapshot) {
                                      final loopMode = snapshot.data ?? LoopMode.off;
                                      return IconButton(
                                        icon: Icon(
                                          loopMode == LoopMode.off
                                              ? Icons.repeat
                                              : loopMode == LoopMode.one
                                                  ? Icons.repeat_one
                                                  : Icons.repeat,
                                          color: loopMode != LoopMode.off
                                              ? Colors.green
                                              : Colors.white54,
                                        ),
                                        onPressed: () {
                                          final modes = [LoopMode.off, LoopMode.all, LoopMode.one];
                                          final currentIndex = modes.indexOf(loopMode);
                                          final nextIndex = (currentIndex + 1) % modes.length;
                                          widget.audioPlayer.setLoopMode(modes[nextIndex]);
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Bottom Actions (Device, Share)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.devices),
                                        color: Colors.white54,
                                        onPressed: () async {
                                          final signalRService = SignalRService();
                                          final devices = await signalRService.getAvailableDevices();
                                          
                                          if (!mounted) return;
                                          
                                          showDialog(
                                            context: context,
                                            builder: (context) => DevicesDialog(
                                              currentDeviceId: signalRService.currentDeviceId ?? 'unknown',
                                              currentDeviceName: signalRService.currentDeviceName ?? 'Thiết bị này',
                                              availableDevices: devices.map((d) => {
                                                'deviceId': d.deviceId,
                                                'deviceName': d.deviceName,
                                                'isActive': d.isActive,
                                              }).toList(),
                                              onDeviceSelected: (deviceId) async {
                                                // Chuyển phát nhạc sang thiết bị được chọn
                                                final currentSong = AudioPlayerService().currentSong;
                                                if (currentSong != null && currentSong.id != null) {
                                                  await signalRService.transferPlayback(
                                                    deviceId,
                                                    currentSong.id!,
                                                    widget.audioPlayer.position,
                                                    widget.audioPlayer.playing,
                                                  );
                                                }
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share),
                                        color: Colors.white54,
                                        onPressed: () {},
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Tiêu đề danh sách bài hát tiếp theo
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 24),
                                    child: Text(
                                      'BÀI HÁT TIẾP THEO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Danh sách bài hát tiếp theo
                                  StreamBuilder<SequenceState?>(
                                    stream: widget.audioPlayer.sequenceStateStream,
                                    builder: (context, snapshot) {
                                      final sequence = snapshot.data?.sequence ?? [];
                                      final currentIndex = snapshot.data?.currentIndex ?? 0;

                                      if (sequence.isEmpty || sequence.length <= 1) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                          child: Text(
                                            'Không có bài hát tiếp theo',
                                            style: TextStyle(color: Colors.white54, fontSize: 14),
                                          ),
                                        );
                                      }

                                      // Hiển thị danh sách các bài sau bài hiện tại
                                      final nextSongs = sequence
                                          .asMap()
                                          .entries
                                          .where((e) => e.key > currentIndex)
                                          .take(3)
                                          .toList();
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: nextSongs.length,
                                        itemBuilder: (context, index) {
                                          final songTag = nextSongs[index].value.tag as Map?;
                                          final songName = songTag?['name'] ?? 'Không rõ tên';
                                          final artist = songTag?['artist'] ?? '';
                                          final img = songTag?['imageUrl'] ?? '';
                                          final imageUrl = img.startsWith('http')
                                              ? img
                                              : (img.isNotEmpty ? 'https://willing-baltimore-brunette-william.trycloudflare.com$img' : '');

                                          return ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                                            leading: ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: imageUrl.isNotEmpty
                                                  ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                                                  : const Icon(Icons.music_note, color: Colors.white54, size: 40),
                                            ),
                                            title: Text(
                                              songName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white, fontSize: 15),
                                            ),
                                            subtitle: artist.isNotEmpty
                                                ? Text(
                                                    artist,
                                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  )
                                                : null,
                                            onTap: () async {
                                              final targetIndex = currentIndex + index + 1;
                                              await widget.audioPlayer.seek(Duration.zero, index: targetIndex);
                                              await widget.audioPlayer.play();
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 30),

                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 24),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'LỜI BÀI HÁT',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 24),
                                    padding: const EdgeInsets.all(16),
                                    height: 400,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: _isLoadingLyric
                                        ? const Center(
                                            child: CircularProgressIndicator(color: Colors.white),
                                          )
                                        : _lyricLines.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'Chưa có lời bài hát',
                                                  style: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              )
                                            : NotificationListener<ScrollNotification>(
                                                onNotification: (notification) {
                                                  // Tắt auto-scroll khi user scroll thủ công
                                                  if (notification is UserScrollNotification) {
                                                    setState(() => _autoScroll = false);
                                                  }
                                                  return false;
                                                },
                                                child: Stack(
                                                  children: [
                                                    ListView.builder(
                                                      controller: _lyricScrollController,
                                                      itemCount: _lyricLines.length,
                                                      padding: const EdgeInsets.only(top: 0, bottom: 180), // Xóa padding top, chỉ giữ bottom để scroll được
                                                      itemBuilder: (context, index) {
                                                        final lyricLine = _lyricLines[index];
                                                        final isActive = index == _currentLyricIndex;
                                                        final isPast = index < _currentLyricIndex;
                                                        final distance = (index - _currentLyricIndex).abs();
                                                        
                                                        // Tính opacity dựa trên khoảng cách với dòng hiện tại
                                                        double opacity = 1.0;
                                                        if (!isActive) {
                                                          opacity = isPast 
                                                              ? 0.3 
                                                              : (1.0 - (distance * 0.15)).clamp(0.4, 1.0);
                                                        }
                                                        
                                                        return GestureDetector(
                                                          onTap: () {
                                                            // Seek đến thời gian của dòng được click
                                                            widget.audioPlayer.seek(lyricLine.time);
                                                            setState(() => _autoScroll = true);
                                                          },
                                                          child: AnimatedContainer(
                                                            duration: const Duration(milliseconds: 300),
                                                            curve: Curves.easeInOut,
                                                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                                                            margin: const EdgeInsets.symmetric(vertical: 6.0),
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(8),
                                                              color: Colors.transparent, // Xóa nền xanh
                                                            ),
                                                            child: AnimatedDefaultTextStyle(
                                                              duration: const Duration(milliseconds: 300),
                                                              curve: Curves.easeInOut,
                                                              style: TextStyle(
                                                                color: isActive
                                                                    ? Colors.greenAccent
                                                                    : Colors.white.withOpacity(opacity),
                                                                fontSize: isActive ? 22 : 16,
                                                                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                                                height: 1.5,
                                                                shadows: isActive ? [
                                                                  Shadow(
                                                                    color: Colors.greenAccent.withOpacity(0.5),
                                                                    blurRadius: 10,
                                                                  ),
                                                                ] : [],
                                                              ),
                                                              child: Text(
                                                                lyricLine.text,
                                                                textAlign: TextAlign.center,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    
                                                    // Nút để bật lại auto-scroll
                                                    if (!_autoScroll)
                                                      Positioned(
                                                        bottom: 16,
                                                        right: 16,
                                                        child: FloatingActionButton.small(
                                                          backgroundColor: Colors.greenAccent,
                                                          onPressed: () {
                                                            setState(() => _autoScroll = true);
                                                            if (_currentLyricIndex >= 0) {
                                                              _scrollToCurrentLyric(_currentLyricIndex);
                                                            }
                                                          },
                                                          child: const Icon(
                                                            Icons.my_location,
                                                            color: Colors.black,
                                                            size: 20,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                  ),
                                  const SizedBox(height: 30),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PositionData {
  final Duration position;
  final Duration duration;
  final bool isPlaying;

  PositionData({
    required this.position,
    required this.duration,
    required this.isPlaying,
  });
}
