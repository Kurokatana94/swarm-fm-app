import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:swarm_fm_app/main.dart';
import 'package:swarm_fm_app/packages/animations.dart';
import 'package:swarm_fm_app/packages/credits.dart';
import 'package:swarm_fm_app/packages/popup.dart';

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
        debugPrint('Screen Height: $screenHeight - Screen Width: $screenWidth');

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

                Text('― Audio Service ―', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),

                ListTile(
                  leading: IgnorePointer(
                    child: Switch(
                      value: activeAudioService == "HLS",
                      inactiveThumbColor: activeTheme['settings_text'],
                      activeThumbColor: activeTheme['settings_bg'],
                      activeTrackColor: activeTheme['settings_text'],
                      inactiveTrackColor: activeTheme['settings_bg'],
                      onChanged: (_) {}
                    ),
                  ),
                  title: Text('HLS', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
                  onTap: () {
                    setState(() {
                      activeAudioService = "HLS";
                    });
                  },
                ),

                ListTile(
                  leading: IgnorePointer(
                    child: Switch(
                      value: activeAudioService == "SHUFFLE",
                      inactiveThumbColor: activeTheme['settings_text'],
                      activeThumbColor: activeTheme['settings_bg'],
                      activeTrackColor: activeTheme['settings_text'],
                      inactiveTrackColor: activeTheme['settings_bg'],
                      onChanged: (_) {}
                    ),
                  ),
                  title: Text('Shuffle', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
                  onTap: () {
                    setState(() {
                      activeAudioService = "SHUFFLE";
                    });
                  },
                ),

                Text('― Info ―', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),

                // Credits page ------------------------------------------------
                ListTile(
                  leading: Icon(Icons.info, color: activeTheme['settings_text'],),
                  title: Text('Credits', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute<void>(builder: (context) => Credits(theme: activeTheme)));
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
                            stream: audioHandler.playbackState,
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
                            stream: audioHandler.playbackState,
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
                            stream: audioHandler.playbackState,
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
                            stream: audioHandler.playbackState,
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
                            stream: audioHandler.playbackState,
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
                          stream: audioHandler.playbackState,
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
                                  await audioHandler.play();
                                },
                              );
                            } else if (processingState == AudioProcessingState.ready && playing == true) {
                              return IconButton(
                                icon: const Icon(Icons.pause),
                                iconSize: 64.0,
                                color: activeTheme['player_controls'],
                                onPressed: () async{
                                  await audioHandler.pause();
                                },
                              );
                            } else {
                              try {
                                  audioHandler.stop(); // stop current playback
                                  audioHandler.play();
                                } catch (e) {
                                  debugPrint('Failed to restart stream: $e');
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