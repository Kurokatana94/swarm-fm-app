import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swarm_fm_app/themes/themes.dart';
import 'package:swarm_fm_app/packages/animations.dart';
import 'package:swarm_fm_app/packages/popup.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lock_orientation_screen/lock_orientation_screen.dart';
import 'dart:io' show Platform;

Map activeTheme = themes['neuro'];

bool isNeuroTheme = true;
bool isEvilTheme = false;
bool isVedalTheme = false;

late AudioHandler _audioHandler;

// Main process init------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  var status = await Permission.notification.status;
  if (status.isDenied) {
    await Permission.notification.request();
  }

  await loadThemeState();

  
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool? isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
  
  _audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.kurokatana94.swarmfm.channel.audio',
      androidNotificationChannelName: 'Swarm FM',
      androidNotificationIcon: "drawable/swarm_fm_icon",
      androidShowNotificationBadge: true,
      androidNotificationOngoing: true,
      androidNotificationClickStartsActivity: true,
    ),
  );

  runApp(MyApp(isFirstLaunch: isFirstLaunch,));
}

// App init ------------------------------------------------
class MyApp extends StatelessWidget {
  final bool isFirstLaunch;
  const MyApp({super.key, required this.isFirstLaunch});
  
  @override
  Widget build(BuildContext context) {
    return LockOrientation( 
      child: MaterialApp(
        title: 'Swarm FM Player',
        theme: ThemeData(fontFamily: 'First Coffee'),
        debugShowCheckedModeBanner: false,
        home: SwarmFMPlayerPage(isFirstLaunch: isFirstLaunch,),
      )
    );
  }
}

class MediaState {
  final MediaItem? mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}

/// An [AudioHandler] for playing a single item (live stream). ------------------------------------------------
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  static final _item = MediaItem(
    id: getStreamUrl(),
    title: "Swarm FM",
  );

  final _player = AudioPlayer();

  AudioPlayerHandler() {
    // Broadcast player state to AudioService (updates notification state)------------------------------------------------
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Broadcast current media item (needed for notification) ------------------------------------------------
    mediaItem.add(_item);

    // Load the audio source ------------------------------------------------
    _player.setAudioSource(AudioSource.uri(Uri.parse(_item.id)));

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
        await _player.setAudioSource(AudioSource.uri(Uri.parse(_item.id)));
        await _player.play();
      }
    });

    // Listen for errors and auto-restart ------------------------------------------------
    _player.playbackEventStream.listen((_) {},
      onError: (Object e, StackTrace stack) async {
        print('Playback error: $e');
        while(!_player.playing){
          try {
            await _player.setUrl(getStreamUrl(), preload: false);
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
    await _player.setAudioSource(AudioSource.uri(Uri.parse(_item.id)));
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


// Main Player Page ------------------------------------------------
class SwarmFMPlayerPage extends StatefulWidget {
  final bool isFirstLaunch;
  const SwarmFMPlayerPage({super.key, required this.isFirstLaunch});
  @override
  State<SwarmFMPlayerPage> createState() => _SwarmFMPlayerPageState();
}

// Main Player Page Active State ------------------------------------------------
class _SwarmFMPlayerPageState extends State<SwarmFMPlayerPage> {
  @override
  void initState() {
  super.initState();

    if (Platform.isAndroid && widget.isFirstLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showBatterySettingsPopup(context);
      });
    }
  }
  // Build the UI ------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder( 
      builder: (BuildContext context, BoxConstraints constraints) {
        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;
        print('Screen Height: $screenHeight - Screen Width: $screenWidth');

        final double titleFontSize = screenWidth * 0.06;
        return Scaffold(
          appBar: AppBar(
            leading: Builder(
              builder: (context) => IconButton(
                icon: SvgPicture.asset(
                  'assets/images/icons/neuro-cog.svg',
                  colorFilter: ColorFilter.mode(
                    activeTheme['control_icons'],
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
            title: Stack(
              children: [
                Text(
                  'Swarm FM Player',
                  style: TextStyle(
                    fontFamily: 'Sobiscuit',
                    fontSize: titleFontSize,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 6
                      ..color = activeTheme['title_outline'],
                  ),
                ),

                Text(
                  'Swarm FM Player',
                  style: TextStyle(
                    fontFamily: 'Sobiscuit',
                    fontSize: titleFontSize,
                    color: activeTheme['title_fill'],
                  ),
                ),
              ]
            ),
            centerTitle: true,
            backgroundColor: activeTheme['app_bar_bg'],
            foregroundColor: activeTheme['app_bar_fg'],
          ),

          // Drawer settings menu ------------------------------------------------
          drawer: Drawer(
            backgroundColor: activeTheme['settings_bg'],
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding:  EdgeInsets.only(top: 40, bottom: 20), 
                  child: Text('Settings', style: TextStyle(color: activeTheme['settings_title'], fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),

                Text('― Themes ―', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),

                // Theme selection options ------------------------------------------------
                // Neuro Theme
                ListTile(
                  leading: IgnorePointer(
                    child: Switch(
                      value: isNeuroTheme,
                      inactiveThumbColor: activeTheme['settings_text'],
                      activeThumbColor: activeTheme['settings_bg'],
                      activeTrackColor: activeTheme['settings_text'],
                      inactiveTrackColor: activeTheme['settings_bg'],
                      onChanged: (isNeuroTheme) {}
                    ),
                  ),
                  title: Text('Neuro', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
                  onTap: () {
                    setState(() {
                      isNeuroTheme = true;
                      isEvilTheme = false;
                      isVedalTheme = false;
                      String name = 'neuro';
                      changeTheme(name);
                      saveThemeState(name, isNeuroTheme, isEvilTheme, isVedalTheme);
                    });
                  },
                ),

                // Evil Theme
                ListTile(
                  leading: IgnorePointer(
                    child: Switch(
                      value: isEvilTheme,
                      inactiveThumbColor: activeTheme['settings_text'],
                      activeThumbColor: activeTheme['settings_bg'],
                      activeTrackColor: activeTheme['settings_text'],
                      inactiveTrackColor: activeTheme['settings_bg'],
                      onChanged: (isEvilTheme) {}
                    ),
                  ),
                  title: Text('Evil', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
                  onTap: () {
                    setState(() {
                      isNeuroTheme = false;
                      isEvilTheme = true;
                      isVedalTheme = false;
                      String name = 'evil';
                      changeTheme(name);
                      saveThemeState(name, isNeuroTheme, isEvilTheme, isVedalTheme);
                    });
                  },
                ),

                // Vedal Theme
                ListTile(
                  leading: IgnorePointer(
                    child: Switch(
                      value: isVedalTheme,
                      inactiveThumbColor: activeTheme['settings_text'],
                      activeThumbColor: activeTheme['settings_bg'],
                      activeTrackColor: activeTheme['settings_text'],
                      inactiveTrackColor: activeTheme['settings_bg'],
                      onChanged: (isVedalTheme) {}
                    ),
                  ),
                  title: Text('Vedal', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
                  onTap: () {
                    setState(() {
                      isNeuroTheme = false;
                      isEvilTheme = false;
                      isVedalTheme = true;
                      String name = 'vedal';
                      changeTheme(name);
                      saveThemeState(name, isNeuroTheme, isEvilTheme, isVedalTheme);
                    });
                  },
                ),

                Text('― Info ―', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),

                // Credits page ------------------------------------------------
                ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Credits', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
                  onTap: () {
                    // TODO: Leads to credits page 
                  },
                ),
              ],
            ),
          ),
          
          backgroundColor: activeTheme['main_bg'],
          
          body: LayoutBuilder( 
            builder: (BuildContext context, BoxConstraints constraints) {
              final double screenWidth = constraints.maxWidth;
              final double screenHeight = constraints.maxHeight;
              return Stack ( 
                children: [ 
                  Positioned(
                    left: 0,
                    top: 0,
                    width: screenWidth,
                    height: screenHeight,
                    child: Stack(
                      children: [
                        // Rotating cog animations ------------------------------------------------
                        // Cog 1
                        Positioned(
                          left: screenWidth -101,
                          top: -90,
                          child: StreamBuilder<PlaybackState>(
                            stream: _audioHandler.playbackState,
                            builder: (context, snapshot) {
                              final playerState = snapshot.data;
                              final playing = playerState?.playing ?? false;

                              return RotatingCog(
                                isSpinning: playing, // starts/stops with the music
                                clockwise: true,
                                icon: SvgPicture.asset(
                                  'assets/images/icons/neuro-cog.svg',
                                  colorFilter: ColorFilter.mode(
                                    activeTheme['animated_icons'],
                                    BlendMode.srcIn,
                                  ),
                                ),
                                size: 200,
                                duration: 6,
                              );
                            },
                          ),
                        ),

                        // Cog 2
                        Positioned(
                          left: screenWidth - 190,
                          top: -31,
                          child: StreamBuilder<PlaybackState>(
                            stream: _audioHandler.playbackState,
                            builder: (context, snapshot) {
                              final playbackState = snapshot.data;
                              final playing = playbackState?.playing ?? false;

                              return RotatingCog(
                                isSpinning: playing, // starts/stops with the music
                                clockwise: false,
                                icon: SvgPicture.asset(
                                  'assets/images/icons/neuro-cog.svg',
                                  colorFilter: ColorFilter.mode(
                                    activeTheme['animated_icons'],
                                    BlendMode.srcIn,
                                  ),
                                ),
                                size: 200,
                                duration: 6,
                              );
                            },
                          ),
                        ),

                        // Cog 3
                        Positioned(
                          left: screenWidth - 296,
                          top: -50,
                          child: StreamBuilder<PlaybackState>(
                            stream: _audioHandler.playbackState,
                            builder: (context, snapshot) {
                              final playerState = snapshot.data;
                              final playing = playerState?.playing ?? false;

                              return RotatingCog(
                                isSpinning: playing, // starts/stops with the music
                                clockwise: true,
                                icon: SvgPicture.asset(
                                  'assets/images/icons/neuro-cog.svg',
                                  colorFilter: ColorFilter.mode(
                                    activeTheme['animated_icons'],
                                    BlendMode.srcIn,
                                  ),
                                ),
                                size: 200,
                                duration: 6,
                              );
                            },
                          ),
                        ),
                      ]
                    )
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    width: screenWidth,
                    height: screenHeight,
                    child: Stack(
                      children: [
                        // Cog 4
                        Positioned(
                          left: - 142,
                          top: screenHeight - 284,
                          child: StreamBuilder<PlaybackState>(
                            stream: _audioHandler.playbackState,
                            builder: (context, snapshot) {
                              final playerState = snapshot.data;
                              final playing = playerState?.playing ?? false;

                              return RotatingCog(
                                isSpinning: playing, // starts/stops with the music
                                icon: SvgPicture.asset(
                                  'assets/images/icons/neuro-cog.svg',
                                  colorFilter: ColorFilter.mode(
                                    activeTheme['animated_icons'],
                                    BlendMode.srcIn,
                                  ),
                                ),
                                size: 400,
                                duration: 15, // slower rotation
                              );
                            },
                          ),
                        ),
                        
                        // Cog 5
                        Positioned(
                          left: 38,
                          top: screenHeight - 162,
                          child: StreamBuilder<PlaybackState>(
                            stream: _audioHandler.playbackState,
                            builder: (context, snapshot) {
                              final playerState = snapshot.data;
                              final playing = playerState?.playing ?? false;

                              return RotatingCog(
                                isSpinning: playing, // starts/stops with the music
                                clockwise: false,
                                icon: SvgPicture.asset(
                                  'assets/images/icons/neuro-cog.svg',
                                  colorFilter: ColorFilter.mode(
                                    activeTheme['animated_icons'],
                                    BlendMode.srcIn,
                                  ),
                                ),
                                size: 400,
                                duration: 15, // slower rotation
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  ),
                  
                  // Main player controls ------------------------------------------------
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[               
                        Image.asset(activeTheme['logo']),

                        StreamBuilder<PlaybackState>(
                          stream: _audioHandler.playbackState,
                          builder: (context, snapshot) {
                            final playerState = snapshot.data;
                            final processingState = playerState?.processingState;
                            final playing = playerState?.playing;

                            if (processingState == AudioProcessingState.loading ||
                                processingState == AudioProcessingState.buffering) {
                              return CircularProgressIndicator(
                                color: activeTheme['player_controls'],
                              );
                            } else if (playing != true) {
                              return IconButton(
                                icon: const Icon(Icons.play_arrow),
                                iconSize: 64.0,
                                color: activeTheme['player_controls'],
                                onPressed: () async {
                                  await _audioHandler.play();
                                },
                              );
                            } else if (processingState == AudioProcessingState.ready && playing == true) {
                              return IconButton(
                                icon: const Icon(Icons.pause),
                                iconSize: 64.0,
                                color: activeTheme['player_controls'],
                                onPressed: () async{
                                  await _audioHandler.pause();
                                },
                              );
                            } else {
                              try {
                                  _audioHandler.stop(); // stop current playback
                                  _audioHandler.play();
                                } catch (e) {
                                  print('Failed to restart stream: $e');
                                }
                              }
                              return CircularProgressIndicator(
                                color: activeTheme['player_controls'],
                              );
                          },
                        ),
                      ],
                    ),
                  ),
                ]
              );
            }
          )
        );
      }
    );
  }
}

// Text outline formatter ------------------------------------------------
List<Text> outlineFormatter(String text, int outlineWidth, Color outlineColor, Color fillColor, double fontSize) {
  List<Text> outlines = [];
  for (int x = -outlineWidth; x <= outlineWidth; x++) {
    for (int y = -outlineWidth; y <= outlineWidth; y++) {
      if (x == 0 && y == 0) continue;
      outlines.add(
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Sobiscuit',
            fontSize: fontSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = outlineColor,
          ),
        ),
      );
    }
  }
  outlines.add(
    Text(
      text,
      style: TextStyle(
        fontFamily: 'Sobiscuit',
        fontSize: fontSize,
        color: fillColor,
      ),
    ),
  );
  return outlines;
}

// Function to change the active theme ------------------------------------------------
void changeTheme(String themeName) {
  if (themes.containsKey(themeName)) {
    activeTheme = themes[themeName];
  }
}

// It simply returns the active stream url, but in future might change depending on how the system evolves ------------------------------------------------
String getStreamUrl() {
  return 'https://customer-x1r232qaorg7edh8.cloudflarestream.com/3a05b1a1049e0f24ef1cd7b51733ff09/manifest/video.m3u8';
}

// Themes saving ------------------------------------------------
Future<void> saveThemeState(String themeName, bool isNeuro, bool isEvil, bool isVedal) async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString('activeTheme', themeName);
  await prefs.setBool('isNeuroTheme', isNeuro);
  await prefs.setBool('isEvilTheme', isEvil);
  await prefs.setBool('isVedalTheme', isVedal);
}

// Theme loading ------------------------------------------------
Future<void> loadThemeState() async {
  final prefs = await SharedPreferences.getInstance();

  String themeName = prefs.getString('activeTheme') ?? 'neuro';

  isNeuroTheme = prefs.getBool('isNeuroTheme') ?? true;
  isEvilTheme = prefs.getBool('isEvilTheme') ?? false;
  isVedalTheme = prefs.getBool('isVedalTheme') ?? false;

  activeTheme = themes[themeName];
}
