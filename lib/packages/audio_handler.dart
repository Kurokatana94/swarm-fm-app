import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:swarm_fm_app/main.dart';
import 'package:swarm_fm_app/utils/general_utils.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:swarm_fm_app/packages/song_data_fetcher.dart';

/// An [AudioHandler] for playing a single item (live stream). ------------------------------------------------
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {

  final _player = AudioPlayer();
  Timer? _metadataTimer;

  MediaItem get _defaultItem => MediaItem(
    id: getStreamUrl(),
    title: "Swarm FM",
    artist: "",   
  );

  AudioPlayerHandler() {
    _initMetadata();

    // Broadcast player state to AudioService (updates notification state)------------------------------------------------
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    if (activeAudioService == "HLS") _player.setAudioSource(AudioSource.uri(Uri.parse(_defaultItem.id)));

    // Keeps the player screen on ------------------------------------------------
    _player.playingStream.listen((isPlaying) {
      if (isPlaying) {
        WakelockPlus.enable();
        _metadataTimer = Timer.periodic(Duration(seconds: 20), (_) async => await _refreshMetadata());
      } else {
        WakelockPlus.disable();
        _metadataTimer?.cancel();
      }
    });
    
    // Listen for idle/failure states and auto-restart ------------------------------------------------
    _player.playerStateStream.listen((playerState) async {
      if (playerState.processingState == ProcessingState.completed) {
        if (activeAudioService == "HLS") {
          await _player.setAudioSource(AudioSource.uri(Uri.parse(_defaultItem.id)));
          await _player.play();
          
          return;
        }
        
        await play();
      }
    });

    // Listen for errors and auto-restart ------------------------------------------------
    _player.playbackEventStream.listen((_) {},
      onError: (Object e, StackTrace stack) async {
        print('Playback error: $e');
        while(!_player.playing){
          try {
            activeAudioService == "HLS" ? await _player.setUrl(getStreamUrl(), preload: false) : await _player.setAudioSource(AudioSource.uri(Uri.parse(getStreamUrl())));
            await _player.play();
          } catch (e) {
            await Future.delayed(const Duration(seconds: 1));
            print('Retry failed: $e');
          }
        }
      }
    );
  }

  Future<void> _initMetadata() async {
    // Show default info immediately
    mediaItem.add(_defaultItem);

    // First fetch
    await _refreshMetadata();
  }

  Future<void> _refreshMetadata() async {
    try {
      SongData songData = await fetchSongData();

      final newItem = MediaItem(
        id: getStreamUrl(),
        title: songData.title,
        artist: "${songData.artist} ft. ${songData.singers.join(', ').toTitleCase}",
      );

      mediaItem.add(newItem);
    } catch (e) {
      print('Failed to fetch song data: $e');
    }
  }

  // Controls ------------------------------------------------
  @override
  Future<void> play() async {
    if (activeAudioService == "SHUFFLE") {
      mediaItem.add(_defaultItem);
      await _player.setAudioSource(AudioSource.uri(Uri.parse(getStreamUrl())));
    } else {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(_defaultItem.id)));
    }
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
    _metadataTimer?.cancel();
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
