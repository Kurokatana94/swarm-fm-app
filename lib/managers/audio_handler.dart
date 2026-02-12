import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:swarm_fm_app/main.dart';
import 'package:swarm_fm_app/utils/general_utils.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:swarm_fm_app/managers/song_data_fetcher.dart';

/// An [AudioHandler] for playing a single item (live stream). ------------------------------------------------
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {

  final _player = AudioPlayer();
  late List<Map<String, dynamic>> _localMetadata = [];
  // Active Stream URL (might change with time)
  final String _STREAM_URL = 'https://stream.sw.arm.fm/new/hls_audio.m3u8';

  Timer? _metadataTimer;
  SongData? _sampleSongData;
  SongData? _currentLiveSongData;
  int _pollingCounter = 0;

  SongData? _currentShuffledSongData;

  bool _isTransitioning = false;

  // TODO - MODIFY TO COMPLY WITH SHUFFLE MODE
  MediaItem get _defaultItem => MediaItem(
    id: _STREAM_URL,
    title: "Swarm FM",
    artist: "",
  );

  AudioPlayerHandler() {
    _initLiveMetadata();

    // Broadcast player state to AudioService (updates notification state)------------------------------------------------
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Keeps the player screen on ------------------------------------------------
    _player.playingStream.listen((isPlaying) {
      if (isPlaying) {
        WakelockPlus.enable();
        _metadataTimer = Timer.periodic(Duration(seconds: _getPollingInterval()), (_) async => await _refreshMetadata());
      } else {
        WakelockPlus.disable();
        _metadataTimer?.cancel();
      }
    });
    
    // Listen for idle/failure states and auto-restart ------------------------------------------------
    _player.playerStateStream.listen((playerState) async {
      if (playerState.processingState == ProcessingState.completed && !_isTransitioning) {
        await play();
      }
    });

    // Listen for errors and auto-restart ------------------------------------------------
    _player.playbackEventStream.listen((_) {},
      onError: (Object e, StackTrace stack) async {
        print('Playback error: $e');
        while(!_player.playing){
          try {
            activeAudioService.value == "HLS" 
              ? await _player.setUrl(_STREAM_URL, preload: false) 
              : await _player.setAudioSource(AudioSource.uri(Uri.parse(await _getRandomSongUrl())));
            await _player.play();
          } catch (e) {
            await Future.delayed(const Duration(seconds: 1));
            print('Retry failed: $e');
          }
        }
      }
    );
    
    activeAudioService.addListener(() async {
      if (_player.playing) await play();
    });
  }

  Future<void> _initLiveMetadata() async {
    // Show default info immediately
    mediaItem.add(_defaultItem);
    _localMetadata = await loadLocalMetadata();

    if (activeAudioService.value == "SHUFFLE") {
      final url = await _getRandomSongUrl();
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(url)),
        preload: false,
      );
      return;
    }

    // First fetch
    await _refreshMetadata();
  }

  Future<void> _refreshMetadata({bool isForced = false}) async {
    try {
      if (!isForced) _currentLiveSongData = await fetchSongData();
      
      final newItem = MediaItem(
        id: activeAudioService.value == "HLS" 
          ? _STREAM_URL
          : _formattedShuffleUrl(),
        title: activeAudioService.value == "HLS"
          ? _currentLiveSongData!.name
          : _currentShuffledSongData!.name,
        artist: activeAudioService.value == "HLS" 
          ? "${_currentLiveSongData!.artist} ft. ${_currentLiveSongData!.singer.join(', ').toTitleCase}"
          : "${_currentShuffledSongData!.artist} ft. ${_currentShuffledSongData!.singer.join(', ').toTitleCase}",
      );

      mediaItem.add(newItem);
    } catch (e) {
      print('Failed to fetch song data: $e');
    }
  }

  Future<String> _getRandomSongUrl() async {
    _localMetadata = await loadLocalMetadata();
    print('!!!!!!!!! Loaded ${_localMetadata.length} songs from local metadata. !!!!!!!!!');
    
    final fetchedSongData = _localMetadata[Random().nextInt(_localMetadata.length)];
    _currentShuffledSongData = SongData(
      id: fetchedSongData['id'],
      name: fetchedSongData['name'],
      artist: fetchedSongData['artist'],
      singer: fetchedSongData['singer'],
      duration: fetchedSongData['duration']);
    
    await _refreshMetadata(isForced: true);

    return _formattedShuffleUrl();
  }

  String _formattedShuffleUrl() {
    return 'https://swarmfm-assets.boopdev.com/music/${_currentShuffledSongData!.id}.mp3';
  }

  // Determines the polling interval for live metadata updates based on the current song's duration and finds the song start within the first to songs streamed ------------------------------------------------
  int _getPollingInterval() {
    try {
      int duration;
      _sampleSongData ??= _currentLiveSongData;

      if (_currentLiveSongData != _sampleSongData && _pollingCounter <= 2) {
        _sampleSongData = _currentLiveSongData;
        _pollingCounter++;
      }
      
      switch (_pollingCounter) {
        case 0:
          duration = 15;
          break;
        case 1:
          duration = _currentLiveSongData!.duration - 15;
          _pollingCounter++;
          break;
        case 2:
          duration = 1;
          break;
        default:
          duration = _currentLiveSongData!.duration;
      }

      return duration;
    } catch (e) {
      return 20;
    }
  }

  // Controls ------------------------------------------------
  @override
  Future<void> play() async {
    // Prevent concurrent play() calls
    if (_isTransitioning) return;
    
    _isTransitioning = true;

    try {      
      if (_player.processingState == ProcessingState.completed || _player.playing) {
        await _player.stop();
      }
      
      if (activeAudioService.value == "SHUFFLE") {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(await _getRandomSongUrl())));
      } else {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(_defaultItem.id)));
      }

      _player.play();
      print('Playback started successfully');
    } catch (e, stackTrace) {
      print('Error in play(): $e');
      print('Stack trace: $stackTrace');
    } finally {
      _isTransitioning = false;
    }
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
