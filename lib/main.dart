import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:swarm_fm_app/themes/themes.dart';
import 'package:swarm_fm_app/packages/animations.dart';

Map activeTheme = themes['neuro'];

bool isNeuroTheme = true;
bool isEvilTheme = false;
bool isVedalTheme = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swarm FM Player',
      theme: ThemeData(
        fontFamily: 'First Coffee',
      ),
      debugShowCheckedModeBanner: false,
      home: const SwarmFMPlayerPage(),
    );
  }
}

// Main Player Page ------------------------------------------------
class SwarmFMPlayerPage extends StatefulWidget {
  const SwarmFMPlayerPage({super.key});
  @override
  State<SwarmFMPlayerPage> createState() => _SwarmFMPlayerPageState();
}

String getStreamUrl() {
  return 'https://customer-x1r232qaorg7edh8.cloudflarestream.com/3a05b1a1049e0f24ef1cd7b51733ff09/manifest/stream_te93df10225cf5ea1c56ba39279850256_r1172253216.m3u8';
}

// Main Player Page Active State ------------------------------------------------
class _SwarmFMPlayerPageState extends State<SwarmFMPlayerPage> {
  late final AudioPlayer _player;
  final String streamurl = getStreamUrl();

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (_initialized) return; // prevent double run
    _initialized = true;

    _player = AudioPlayer();
    _player.playerStateStream.listen(_onPlayerStateChanged);
    _player.playbackEventStream.handleError((error, stack) {
      print("Playback error: $error");
      _retry();
    });

    _setupAudio();
  }

  void _onPlayerStateChanged(PlayerState state) async {
    if (state.processingState == ProcessingState.buffering &&
        state.playing &&
        _player.bufferedPosition < _player.position) {
      print("⚠️ Buffer underrun → resyncing to live edge");
      try {
        await _player.seek(Duration.zero, index: _player.effectiveIndices.last);
      } catch (e) {
        print("Resync failed: $e");
      }
    } else if (state.processingState == ProcessingState.idle && !_player.playing) {
      _retry();
    }
  }

  bool _retrying = false;

  Future<void> _retry([int delay = 3]) async {
    if (_retrying) return; // prevent multiple overlapping retries
    _retrying = true;

    print("Retrying in $delay seconds...");
    await Future.delayed(Duration(seconds: delay));
    try {
      await _player.setUrl(streamurl); // try plain setUrl first
      await _player.play();
    } catch (e) {
      print("Retry failed: $e");
      _retrying = false;
      _retry(delay * 2); // exponential backoff
      return;
    }
    _retrying = false;
  }

  Future<void> _setupAudio() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    try {
      await _player.setAudioSource(HlsAudioSource(Uri.parse(streamurl)), preload: true);

      // Wait until some data is buffered
      while (_player.bufferedPosition < const Duration(seconds: 1)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      await _player.play();
    } catch (e) {
      print("Error loading audio source: $e");
      _retry();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }


  // TODO Add player decorations, like cogs and gifs
  // Build the UI ------------------------------------------------
  @override
  Widget build(BuildContext context) {
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
                fontSize: 28,
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
                fontSize: 28,
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
            // TODO Fix switch visual behaviour
            // Neuro Theme
            ListTile(
              leading: Switch(
                value: isNeuroTheme,
                inactiveThumbColor: activeTheme['settings_text'],
                activeThumbColor: activeTheme['settings_bg'],
                activeTrackColor: activeTheme['settings_text'],
                inactiveTrackColor: activeTheme['settings_bg'],
                onChanged: (isNeuroTheme) {}
              ),
              title: Text('Neuro', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
              onTap: () {
                setState(() {
                  isNeuroTheme = true;
                  isEvilTheme = false;
                  isVedalTheme = false;
                  changeTheme('neuro');
                });
              },
            ),

            // Evil Theme
            ListTile(
              leading: Switch(
                value: isEvilTheme,
                inactiveThumbColor: activeTheme['settings_text'],
                activeThumbColor: activeTheme['settings_bg'],
                activeTrackColor: activeTheme['settings_text'],
                inactiveTrackColor: activeTheme['settings_bg'],
                onChanged: (isEvilTheme) {}
              ),
              title: Text('Evil', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
              onTap: () {
                setState(() {
                  isNeuroTheme = false;
                  isEvilTheme = true;
                  isVedalTheme = false;
                  changeTheme('evil');
                });
              },
            ),

            // Vedal Theme
            ListTile(
              leading: Switch(
                value: isVedalTheme,
                inactiveThumbColor: activeTheme['settings_text'],
                activeThumbColor: activeTheme['settings_bg'],
                activeTrackColor: activeTheme['settings_text'],
                inactiveTrackColor: activeTheme['settings_bg'],
                onChanged: (isVedalTheme) {}
              ),
              title: Text('Vedal', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
              onTap: () {
                setState(() {
                  isNeuroTheme = false;
                  isEvilTheme = false;
                  isVedalTheme = true;
                  changeTheme('vedal');
                });
              },
            ),

            Text('― Info ―', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),

            // Credits page ------------------------------------------------
            ListTile(
              leading: Icon(Icons.info),
              title: Text('Credits', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
              onTap: () {
                // Leads to credits page
              },
            ),
          ],
        ),
      ),
      
      backgroundColor: activeTheme['main_bg'],

      // TODO NURU/ENURU for loading icon
      
      body: Stack(
        children: [

          // Rotating cog animations ------------------------------------------------
          // Cog 1
          Positioned(
            left: 310,
            top: -90,
            child: StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
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
            left: 221,
            top: -31,
            child: StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
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
                  size: 200,
                  duration: 6,
                );
              },
            ),
          ),

          // Cog 3
          Positioned(
            left: 115,
            top: -50,
            child: StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
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
          
          // Cog 4
          Positioned(
            left: -140,
            top: 570,
            child: StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
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
            left: 40,
            top: 700,
            child: StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
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
          
          // Main player controls ------------------------------------------------
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[               
                Image.asset(activeTheme['logo']),

                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snapshot) {
                    final playerState = snapshot.data;
                    final processingState = playerState?.processingState;
                    final playing = playerState?.playing;

                    if (processingState == ProcessingState.loading ||
                        processingState == ProcessingState.buffering) {
                      return CircularProgressIndicator(
                        color: activeTheme['player_controls'],
                      );
                    } else if (playing != true) {
                      return IconButton(
                        icon: const Icon(Icons.play_arrow),
                        iconSize: 64.0,
                        color: activeTheme['player_controls'],
                        onPressed: () async {
                          await _setupAudio();
                        },
                      );
                    } else if (processingState != ProcessingState.completed) {
                      return IconButton(
                        icon: const Icon(Icons.pause),
                        iconSize: 64.0,
                        color: activeTheme['player_controls'],
                        onPressed: () async{
                          await _player.pause();
                        },

                      );
                    } else {
                      return IconButton(
                        icon: const Icon(Icons.replay),
                        iconSize: 64.0,
                        color: activeTheme['player_controls'],
                        onPressed: () => _player.seek(Duration.zero),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ]
      )
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

void changeTheme(String themeName) {
  // Function to change the active theme
  if (themes.containsKey(themeName)) {
    activeTheme = themes[themeName];
  }
}