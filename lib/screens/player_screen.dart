import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/music_api_service.dart';
import 'package:rxdart/rxdart.dart';
import '../services/audio_player_service.dart';
import '../models/lyric_line.dart';
import '../widgets/devices_dialog.dart';
import '../services/signalr_service.dart';
import '../theme.dart';

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
  final ScrollController _lyricScrollController = ScrollController();
  bool _autoScroll = true;

  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest4<Duration, Duration?, bool, Duration?, PositionData>(
        widget.audioPlayer.positionStream,
        widget.audioPlayer.durationStream,
        widget.audioPlayer.playingStream,
        AudioPlayerService().remotePositionStream,
        (position, duration, isPlaying, remotePosition) {
          Duration finalDuration = Duration.zero;
          if (duration != null && duration.inMilliseconds > 0) {
            finalDuration = duration;
          } else {
            finalDuration = AudioPlayerService().currentSong?.durationFallback ?? Duration.zero;
          }
          
          // Nếu không đang phát và có remote position, hiển thị remote position
          Duration displayPosition = position;
          if (!isPlaying && remotePosition != null) {
            displayPosition = remotePosition;
          }
          
          return PositionData(position: displayPosition, duration: finalDuration, isPlaying: isPlaying);
        },
      ).distinct();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);

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

    widget.audioPlayer.positionStream.listen((position) {
      if (mounted && _lyricLines.isNotEmpty) {
        _updateCurrentLyric(position);
      }
    });

    widget.audioPlayer.sequenceStateStream.listen((seq) {
      if (mounted) setState(() {});
    });

    widget.audioPlayer.currentIndexStream.listen((idx) {
      if (mounted) setState(() {});
    });

    _loadLyric();
  }

  void _updateCurrentLyric(Duration position) {
    if (_lyricLines.isEmpty) return;
    int newIndex = -1;
    for (int i = 0; i < _lyricLines.length; i++) {
      if (position >= _lyricLines[i].time) {
        newIndex = i;
      } else {
        break;
      }
    }
    if (newIndex != _currentLyricIndex) {
      setState(() => _currentLyricIndex = newIndex);
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
        if (text.isNotEmpty) {
          final time = Duration(minutes: minutes, seconds: seconds, milliseconds: hundredths * 10);
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
    _lyricScrollController.dispose();
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
      _controller.forward().then((_) => Navigator.pop(context));
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

  void _scrollToCurrentLyric(int index) {
    if (!_lyricScrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_lyricScrollController.hasClients) return;
      final double itemHeight = 58.0;
      final double containerHeight = 400.0;
      final double targetOffset = (index * itemHeight) - (containerHeight * 0.25);
      final double clampedOffset = targetOffset.clamp(0.0, _lyricScrollController.position.maxScrollExtent);
      _lyricScrollController.animateTo(clampedOffset, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
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
          final positionData = snapshot.data ?? PositionData(position: Duration.zero, duration: Duration.zero, isPlaying: false);

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
                          const Color(0xFF535353),
                          SpotifyTheme.background,
                        ],
                        stops: const [0.0, 0.5],
                      ),
                    ),
                    child: Scaffold(
                      backgroundColor: Colors.transparent,
                      appBar: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, size: 32, color: SpotifyTheme.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                        title: Column(
                          children: [
                            Text('ĐANG PHÁT TỪ', style: SpotifyTheme.labelMedium),
                            const SizedBox(height: 2),
                            Text('Đề xuất cho bạn', style: SpotifyTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        centerTitle: true,
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.more_vert, color: SpotifyTheme.textPrimary),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      body: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            // Album Art
                            _buildAlbumArt(size),
                            const SizedBox(height: 32),
                            // Song Info & Controls
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  _buildSongInfo(),
                                  const SizedBox(height: 24),
                                  _buildProgressBar(positionData),
                                  const SizedBox(height: 16),
                                  _buildPlaybackControls(positionData),
                                  const SizedBox(height: 16),
                                  _buildBottomActions(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Next songs section
                            _buildNextSongsSection(),
                            const SizedBox(height: 24),
                            // Lyrics section
                            _buildLyricsSection(),
                            const SizedBox(height: 40),
                          ],
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

  Widget _buildAlbumArt(Size size) {
    return StreamBuilder<SequenceState?>(
      stream: widget.audioPlayer.sequenceStateStream,
      builder: (context, seqSnap) {
        final tag = seqSnap.data?.currentSource?.tag as Map?;
        final rawImage = (tag is Map && tag['imageUrl'] != null)
            ? tag['imageUrl'] as String
            : (AudioPlayerService().currentSong?.imageUrl ?? widget.currentSong.imageUrl ?? '');
        final imageUrl = rawImage.startsWith('http') ? rawImage : (rawImage.isNotEmpty ? 'https://difficulties-filled-did-announce.trycloudflare.com$rawImage' : rawImage);

        return Container(
          width: size.width - 48,
          height: size.width - 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: SpotifyTheme.cardHover,
                child: const Icon(Icons.music_note, color: SpotifyTheme.textMuted, size: 80),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSongInfo() {
    return StreamBuilder<SequenceState?>(
      stream: widget.audioPlayer.sequenceStateStream,
      builder: (context, seqSnap) {
        final tag = seqSnap.data?.currentSource?.tag as Map?;
        final displayName = (tag is Map && tag['name'] != null)
            ? tag['name'] as String
            : (AudioPlayerService().currentSong?.name ?? widget.currentSong.name ?? 'Unknown');

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: SpotifyTheme.headingSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('Nghệ sĩ', style: SpotifyTheme.bodyMedium),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.favorite_border, color: SpotifyTheme.textSecondary),
              onPressed: () {},
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressBar(PositionData positionData) {
    return Column(
      children: [
        SliderTheme(
          data: Theme.of(context).sliderTheme.copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            min: 0,
            max: positionData.duration.inMilliseconds.toDouble() == 0 ? 1 : positionData.duration.inMilliseconds.toDouble(),
            value: positionData.duration.inMilliseconds > 0
                ? positionData.position.inMilliseconds.toDouble().clamp(0, positionData.duration.inMilliseconds.toDouble())
                : 0,
            onChanged: positionData.duration.inMilliseconds > 0
                ? (value) => widget.audioPlayer.seek(Duration(milliseconds: value.round()))
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(positionData.position), style: SpotifyTheme.bodySmall),
              Text(positionData.duration.inMilliseconds > 0 ? _formatDuration(positionData.duration) : '--:--', style: SpotifyTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls(PositionData positionData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        StreamBuilder<bool>(
          stream: widget.audioPlayer.shuffleModeEnabledStream,
          builder: (context, snapshot) {
            final isEnabled = snapshot.data ?? false;
            return IconButton(
              icon: Icon(Icons.shuffle, color: isEnabled ? SpotifyTheme.primary : SpotifyTheme.textSecondary),
              onPressed: () => widget.audioPlayer.setShuffleModeEnabled(!isEnabled),
            );
          },
        ),
        IconButton(
          iconSize: 40,
          icon: Icon(Icons.skip_previous, color: widget.audioPlayer.hasPrevious ? SpotifyTheme.textPrimary : SpotifyTheme.textMuted),
          onPressed: widget.audioPlayer.hasPrevious ? () => widget.audioPlayer.seekToPrevious() : null,
        ),
        GestureDetector(
          onTap: () async {
            if (widget.audioPlayer.playing) {
              await AudioPlayerService().pause();
            } else {
              await AudioPlayerService().play();
            }
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: SpotifyTheme.textPrimary,
              shape: BoxShape.circle,
            ),
            child: Icon(positionData.isPlaying ? Icons.pause : Icons.play_arrow, size: 36, color: SpotifyTheme.background),
          ),
        ),
        IconButton(
          iconSize: 40,
          icon: Icon(Icons.skip_next, color: widget.audioPlayer.hasNext ? SpotifyTheme.textPrimary : SpotifyTheme.textMuted),
          onPressed: widget.audioPlayer.hasNext
              ? () async {
                  await widget.audioPlayer.seekToNext();
                  await AudioPlayerService().play();
                }
              : null,
        ),
        StreamBuilder<LoopMode>(
          stream: widget.audioPlayer.loopModeStream,
          builder: (context, snapshot) {
            final loopMode = snapshot.data ?? LoopMode.off;
            return IconButton(
              icon: Icon(
                loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                color: loopMode != LoopMode.off ? SpotifyTheme.primary : SpotifyTheme.textSecondary,
              ),
              onPressed: () {
                final modes = [LoopMode.off, LoopMode.all, LoopMode.one];
                final nextIndex = (modes.indexOf(loopMode) + 1) % modes.length;
                widget.audioPlayer.setLoopMode(modes[nextIndex]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.speaker_group_outlined, color: SpotifyTheme.textSecondary),
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
                  'connectionId': d.connectionId,
                  'deviceName': d.deviceName, 
                  'isActive': d.isActive,
                  'isCurrentDevice': d.isCurrentDevice,
                }).toList(),
                onDeviceSelected: (deviceId) async {
                  final currentSong = AudioPlayerService().currentSong;
                  if (currentSong != null && currentSong.id != null) {
                    final success = await signalRService.transferPlayback(
                      deviceId, 
                      currentSong.id!, 
                      widget.audioPlayer.position, 
                      widget.audioPlayer.playing,
                      songName: currentSong.name ?? currentSong.fileName ?? '',
                      imageUrl: currentSong.imageUrl ?? '',
                      artistName: '',
                    );
                    
                    if (success) {
                      // Dừng phát nhạc trên thiết bị này sau khi transfer
                      await widget.audioPlayer.pause();
                    }
                  }
                },
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.playlist_play, color: SpotifyTheme.textSecondary),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: SpotifyTheme.textSecondary),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildNextSongsSection() {
    return StreamBuilder<SequenceState?>(
      stream: widget.audioPlayer.sequenceStateStream,
      builder: (context, snapshot) {
        final sequence = snapshot.data?.sequence ?? [];
        final currentIndex = snapshot.data?.currentIndex ?? 0;

        if (sequence.isEmpty || sequence.length <= 1) {
          return const SizedBox.shrink();
        }

        final nextSongs = sequence.asMap().entries.where((e) => e.key > currentIndex).take(3).toList();
        if (nextSongs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Bài hát tiếp theo', style: SpotifyTheme.headingSmall),
            ),
            const SizedBox(height: 12),
            ...nextSongs.map((entry) {
              final songTag = entry.value.tag as Map?;
              final songName = songTag?['name'] ?? 'Không rõ tên';
              final img = songTag?['imageUrl'] ?? '';
              final imageUrl = img.startsWith('http') ? img : (img.isNotEmpty ? 'https://difficulties-filled-did-announce.trycloudflare.com$img' : '');

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover)
                      : Container(width: 48, height: 48, color: SpotifyTheme.cardHover, child: const Icon(Icons.music_note, color: SpotifyTheme.textMuted)),
                ),
                title: Text(songName, style: SpotifyTheme.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('Nghệ sĩ', style: SpotifyTheme.bodySmall),
                onTap: () async {
                  final targetIndex = currentIndex + nextSongs.indexOf(entry) + 1;
                  await widget.audioPlayer.seek(Duration.zero, index: targetIndex);
                  await AudioPlayerService().play();
                },
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildLyricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('Lời bài hát', style: SpotifyTheme.headingSmall),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          height: 350,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF4A3728),
                const Color(0xFF2A1F18),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isLoadingLyric
              ? const Center(child: CircularProgressIndicator(color: SpotifyTheme.textPrimary))
              : _lyricLines.isEmpty
                  ? Center(child: Text('Chưa có lời bài hát', style: SpotifyTheme.bodyMedium))
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
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
                            padding: const EdgeInsets.only(bottom: 100),
                            itemBuilder: (context, index) {
                              final lyricLine = _lyricLines[index];
                              final isActive = index == _currentLyricIndex;
                              final isPast = index < _currentLyricIndex;

                              return GestureDetector(
                                onTap: () {
                                  widget.audioPlayer.seek(lyricLine.time);
                                  setState(() => _autoScroll = true);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    style: TextStyle(
                                      color: isActive ? SpotifyTheme.textPrimary : (isPast ? SpotifyTheme.textMuted : SpotifyTheme.textSecondary),
                                      fontSize: isActive ? 24 : 18,
                                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                                      height: 1.4,
                                    ),
                                    child: Text(lyricLine.text),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (!_autoScroll)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: FloatingActionButton.small(
                                backgroundColor: SpotifyTheme.textPrimary,
                                onPressed: () {
                                  setState(() => _autoScroll = true);
                                  if (_currentLyricIndex >= 0) _scrollToCurrentLyric(_currentLyricIndex);
                                },
                                child: const Icon(Icons.my_location, color: SpotifyTheme.background, size: 18),
                              ),
                            ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

class PositionData {
  final Duration position;
  final Duration duration;
  final bool isPlaying;

  PositionData({required this.position, required this.duration, required this.isPlaying});
}
