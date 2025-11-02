import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.soundaudio.channel.audio',
      androidNotificationChannelName: 'Sound Audio',
      androidNotificationOngoing: true,
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    try {
      await _player.setUrl(mediaItem.id);
      await _player.play();
    } catch (e) {
      print("❌ Lỗi phát nhạc: $e");
    }
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
}
