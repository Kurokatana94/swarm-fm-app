import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:swarm_fm_app/main.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// An [AudioHandler] for playing a single item (live stream). ------------------------------------------------
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  // MODIFIED: Changed from 'static final _item' to a dynamic getter
  // static final _item = MediaItem(id: getStreamUrl(), title: "Swarm FM");
  MediaItem get _item => MediaItem(
    id: getStreamUrl(),
    title: "Swarm FM",
  );
  
  final _player = AudioPlayer();

  AudioPlayerHandler() {
    // Broadcast player state to AudioService (updates notification state)------------------------------------------------
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Broadcast current media item (needed for notification) ------------------------------------------------
    mediaItem.add(_item);

    // MODIFIED: Removed the static setAudioSource from constructor to allow fresh URL on play
    // _player.setAudioSource(AudioSource.uri(Uri.parse(_item.id)));

    // Keeps the player screen on ------------------------------------------------
    _player.playingStream.listen((isPlaying) {
      if (isPlaying) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    });
    
    // Listen for idle/failure states and auto-restart ------------------------------------------------
    _player.playerStateStream.listen((playerState) async {
      if (playerState.processingState == ProcessingState.completed) {
        // MODIFIED: Triggers the play() method which now handles the next random URL
        // await _player.setAudioSource(AudioSource.uri(Uri.parse(_item.id)));
        await play();
      }
    });

    // Listen for errors and auto-restart ------------------------------------------------
    _player.playbackEventStream.listen((_) {},
      onError: (Object e, StackTrace stack) async {
        print('Playback error: $e');
        while(!_player.playing){
          try {
            // MODIFIED: Fetches the fresh randomized URL on retry
            // await _player.setUrl(getStreamUrl(), preload: false);
            await _player.setAudioSource(AudioSource.uri(Uri.parse(getStreamUrl())));
            await _player.play();
          } catch (e) {
            await Future.delayed(const Duration(seconds: 1));
            print('Retry failed: $e');
          }
        }
      }
    );
  }

  // Controls ------------------------------------------------
  @override
  Future<void> play() async {
    // MODIFIED: Every time play is called, it re-fetches the random URL from main.dart
    // await _player.setAudioSource(AudioSource.uri(Uri.parse(_item.id)));
    mediaItem.add(_item);
    await _player.setAudioSource(AudioSource.uri(Uri.parse(getStreamUrl())));
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    await _player.dispose();
    return super.onTaskRemoved();
  }

  // Notification handler (lockscreen and notification bar player controller) ------------------------------------------------
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
      ],
      androidCompactActionIndices: const [0],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}