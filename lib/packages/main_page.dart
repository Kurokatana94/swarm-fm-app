import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:swarm_fm_app/main.dart';
import 'package:swarm_fm_app/packages/animations.dart';
import 'package:swarm_fm_app/packages/credits.dart';
import 'package:swarm_fm_app/packages/popup.dart';
import 'package:swarm_fm_app/packages/chat_panel.dart';
import 'package:swarm_fm_app/packages/providers/chat_providers.dart';
import 'package:swarm_fm_app/packages/providers/websocket_provider.dart';
import 'package:swarm_fm_app/packages/services/fpwebsockets.dart';

// Main Player Page ------------------------------------------------
class SwarmFMPlayerPage extends ConsumerStatefulWidget {
  final bool isFirstLaunch;
  const SwarmFMPlayerPage({super.key, required this.isFirstLaunch});
  @override
  ConsumerState<SwarmFMPlayerPage> createState() => _SwarmFMPlayerPageState();
}

// Main Player Page Active State ------------------------------------------------
class _SwarmFMPlayerPageState extends ConsumerState<SwarmFMPlayerPage>
    with TickerProviderStateMixin {

  bool _isChatEnabled = true;
  bool _isChatOpen = false;
  double _chatHeightFactor = 1 / 3;
  double _chatButtonDragAngle = 0;
  late AnimationController _chatAnimationController;
  late Animation<double> _chatSlideAnimation;
  late AnimationController _chatButtonSpinController;
  late Animation<double> _chatButtonSpinAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize chat animation controller
    _chatAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _chatSlideAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _chatAnimationController, curve: Curves.easeInOut),
    );

    _chatButtonSpinController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _chatButtonSpinAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _chatButtonSpinController, curve: Curves.easeInOut),
    );

    // Initialize WebSocket and request chat history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });

    if (Platform.isAndroid && widget.isFirstLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showBatterySettingsPopup(context);
      });
    }
  }

  Future<void> _initializeChat() async {
    try {
      // Register the WebSocket event handler
      final fpWebsockets = ref.read(fpWebsocketsProvider);
      final eventHandler = ref.read(webSocketEventHandlerProvider);
      
      // Register listener for incoming messages
      fpWebsockets.registerListener(eventHandler.messagesHandler);
      
      // Request chat history
      fpWebsockets.historyRequest();
    } catch (e) {
      print('Error initializing chat: $e');
    }
  }

  @override
  void dispose() {
    _chatAnimationController.dispose();
    _chatButtonSpinController.dispose();
    super.dispose();
  }

  void _toggleChat() {
    final bool opening = !_isChatOpen;
    _startChatButtonSpin(opening: opening);
    setState(() {
      _isChatOpen = !_isChatOpen;
    });
    if (_isChatOpen) {
      _chatAnimationController.forward();
    } else {
      _chatAnimationController.reverse();
    }
  }

  void _startChatButtonSpin({required bool opening}) {
    final double currentSpin = _chatButtonSpinAnimation.value;
    final double totalAngle = _chatButtonDragAngle + currentSpin;
    final double tau = 2 * pi;
    final double normalized = ((totalAngle % tau) + tau) % tau;
    
    final double increment = opening
      ? -tau // anticlockwise when opening
      : (tau - normalized); // clockwise to straight when closing

    _chatButtonSpinAnimation = Tween<double>(
      begin: currentSpin,
      end: currentSpin + increment,
    ).animate(
      CurvedAnimation(parent: _chatButtonSpinController, curve: Curves.easeInOut),
    );
    _chatButtonSpinController.forward(from: 0);
  }

  // Build the UI ------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder( 
      builder: (BuildContext context, BoxConstraints constraints) {
        final double screenWidth = constraints.maxWidth;

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
                
                Text('― Chat ―', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                
                // Twitch Chat Options ------------------------------------------------
                ListTile(
                  leading: Switch(
                    value: _isChatEnabled,
                    inactiveThumbColor: activeTheme['settings_text'],
                    activeThumbColor: activeTheme['settings_bg'],
                    activeTrackColor: activeTheme['settings_text'],
                    inactiveTrackColor: activeTheme['settings_bg'],
                    onChanged: (_) {
                      setState(() {
                        _isChatEnabled = !_isChatEnabled;
                      });
                    }
                  ),
                  title: Text(_isChatEnabled ? 'On' : 'Off', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
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

                  // Chat Panel (slides up from bottom) ------------------------------------------------
                  if (_isChatEnabled)
                    Consumer(
                      builder: (context, ref, child) {
                        final messages = ref.watch(chatProvider);
                        return ChatPanel(
                          slideAnimation: _chatSlideAnimation,
                          theme: activeTheme,
                          heightFactor: _chatHeightFactor,
                          messages: messages,
                          onHeightFactorChanged: (value) {
                            setState(() {
                              _chatHeightFactor = value;
                            });
                          },
                          onDragDelta: (deltaRatio) {
                            setState(() {
                              const double rotationsPerScreen = 6;
                              _chatButtonDragAngle +=
                                  -deltaRatio * (2 * pi * rotationsPerScreen);
                            });
                          },
                        );
                      },
                    ),

                  // Chat button (bottom-right corner) ------------------------------------------------
                  if (_isChatEnabled)
                    Positioned(
                      bottom: 15,
                      right: 10,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _chatSlideAnimation,
                          _chatButtonSpinController,
                        ]),
                        builder: (context, child) {
                          final double spinAngle = _chatButtonSpinAnimation.value;
                          return Transform.rotate(
                            angle: (_chatButtonDragAngle + spinAngle),
                            child: GestureDetector(
                              onTap: _toggleChat,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Background layer
                                  SvgPicture.asset(
                                    'assets/images/icons/chat-icon-bg.svg',
                                    width: 56,
                                    height: 56,
                                    colorFilter: ColorFilter.mode(
                                      activeTheme['chat_icon_bg'],
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  // Foreground layer
                                  SvgPicture.asset(
                                    'assets/images/icons/chat-icon.svg',
                                    width: 56,
                                    height: 56,
                                    colorFilter: ColorFilter.mode(
                                      activeTheme['chat_icon_fg'],
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  
                  // Main player controls ------------------------------------------------
                  AnimatedBuilder(
                    animation: _chatSlideAnimation,
                    builder: (context, child) {
                      final double panelHeight =
                          screenHeight * _chatHeightFactor;
                      final double offsetY = _isChatEnabled
                          ? -(panelHeight / 2) * _chatSlideAnimation.value
                          : 0;
                      final double baseSpacing = 0; // No spacing between logo and button

                      return Transform.translate(
                        offset: Offset(0, offsetY),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              // Logo
                              Image.asset(activeTheme['logo']),
                              // Fixed spacing
                              SizedBox(height: baseSpacing),
                              // Play button
                              StreamBuilder<PlaybackState>(
                                  stream: audioHandler.playbackState,
                                  builder: (context, snapshot) {
                                    final playerState = snapshot.data;
                                    final processingState =
                                        playerState?.processingState;
                                    final playing = playerState?.playing;

                                    if (processingState == AudioProcessingState.loading ||
                                        processingState == AudioProcessingState.buffering) {
                                      return CircularProgressIndicator(
                                        color: activeTheme['player_controls'],
                                        padding: EdgeInsets.all(22),
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
                      );
                    },
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