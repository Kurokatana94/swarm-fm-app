import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:swarm_fm_app/main.dart';
import 'package:swarm_fm_app/packages/components/animations.dart';
import 'package:swarm_fm_app/packages/popups/battery_warning_popup.dart';
import 'package:swarm_fm_app/packages/ui/chat_panel.dart';
import 'package:swarm_fm_app/packages/providers/chat_providers.dart' as chat_providers;
import 'package:swarm_fm_app/packages/providers/websocket_provider.dart';
import 'package:swarm_fm_app/packages/ui/drawer.dart';
import 'package:swarm_fm_app/packages/providers/chat_login_provider.dart';
import 'package:swarm_fm_app/packages/providers/theme_provider.dart';
import 'package:swarm_fm_app/managers/chat_manager.dart';
import 'package:swarm_fm_app/packages/providers/chat_providers.dart';

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
  static const double _buttonSize = 56.0;
  static const double _buttonBottomInset = 15.0;
  static const double _rotationsPerPanel = 6.0;

  bool _isChatOpen = false;
  double _chatHeightFactor = 1 / 3;
  double _chatButtonDragAngle = 0;
  late AnimationController _chatAnimationController;
  late Animation<double> _chatSlideAnimation;
  late AnimationController _chatButtonSpinController;
  late Animation<double> _chatButtonSpinAnimation;

  double _buttonBottom = _buttonBottomInset;
  bool _isDraggingButton = false;
  ProviderSubscription<double>? _scrollSubscription;
  double _dragStartBottom = _buttonBottomInset;
  double _dragStartDy = 0.0;
  bool _isAnimatingClose = false;
  double _buttonBottomBeforeClose = _buttonBottomInset;

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

    _chatAnimationController.addListener(_onCloseAnimationTick);
    _chatAnimationController.addStatusListener(_onCloseAnimationStatus);

    _chatButtonSpinController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _chatButtonSpinAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _chatButtonSpinController, curve: Curves.easeInOut),
    );

    _scrollSubscription = ref.listenManual<double>(
      chat_providers.chatScrollProvider,
      (previous, next) {
        if (!_isChatOpen || _isDraggingButton || previous == null) {
          return;
        }
        final maxScroll = ref.read(chat_providers.chatScrollProvider.notifier).maxScrollExtent;
        if (maxScroll <= 0) {
          return;
        }
        final delta = next - previous;
        if (delta == 0) {
          return;
        }
        setState(() {
          // Positive delta (scrolling down) rotates counterclockwise.
          _chatButtonDragAngle -= (delta / maxScroll) * (2 * pi * _rotationsPerPanel);
        });
      },
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
    _scrollSubscription?.close();
    _chatAnimationController.removeListener(_onCloseAnimationTick);
    _chatAnimationController.removeStatusListener(_onCloseAnimationStatus);
    _chatAnimationController.dispose();
    _chatButtonSpinController.dispose();
    super.dispose();
  }

  void _sendChatMessage(String message) async {
    final isLoggedIn = ref.read(chatLoginProvider);
    if (isLoggedIn) {
      final fpWebsockets = ref.read(fpWebsocketsProvider);
      fpWebsockets.sendChatMessage(message);
    } else {
      final chatManager = ChatManager();
      final session = await chatManager.fetchSession();
      if (session != null && session.isNotEmpty) {
        final fpWebsockets = ref.read(fpWebsocketsProvider);
        final username = await fpWebsockets.authorise(session);
        if (username.isNotEmpty && mounted) {
          ref.read(chatLoginProvider.notifier).setLoggedIn(true);
          fpWebsockets.sendChatMessage(message);
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to send messages'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onCloseAnimationTick() {
    if (_isAnimatingClose) {
      setState(() {});
    }
  }

  void _onCloseAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _isAnimatingClose) {
      setState(() {
        _isAnimatingClose = false;
        _buttonBottom = _buttonBottomInset;
        // Zero drag angle AND spin animation together so total = 0 + 0 = straight.
        _chatButtonDragAngle = 0;
        _chatButtonSpinAnimation = Tween<double>(begin: 0, end: 0).animate(
          CurvedAnimation(parent: _chatButtonSpinController, curve: Curves.easeInOut),
        );
      });
      // Reset scroll to bottom AFTER animation completes to avoid heavy
      // ListView relayout blocking animation frames.
      final scrollNotifier = ref.read(chat_providers.chatScrollProvider.notifier);
      scrollNotifier.setScrollOffset(scrollNotifier.maxScrollExtent);
    }
  }

  void _toggleChat() {
    final bool opening = !_isChatOpen;
    if (!opening) {
      // Save current button position before closing
      _isAnimatingClose = true;
      _buttonBottomBeforeClose = _buttonBottom;
      debugPrint('TOGGLE CLOSE: saved=$_buttonBottomBeforeClose');
    } else {
      _isAnimatingClose = false;
    }
    _startChatButtonSpin(opening: opening);
    setState(() {
      _isChatOpen = !_isChatOpen;
      if (!_isChatOpen) {
        _isDraggingButton = false;
      }
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
    final themeState = ref.watch(themeProvider);
    final activeTheme = themeState.theme;

    final isChatEnabled = ref.watch(isChatEnabledProvider);
    
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
          drawer: AppDrawer(), 
          
          backgroundColor: activeTheme['main_bg'],
          
          // Main content with rotating cogs, player controls, and chat panel ------------------------------------------------
          body: LayoutBuilder( 
            builder: (BuildContext context, BoxConstraints constraints) {
              final double screenWidth = constraints.maxWidth;
              final double screenHeight = constraints.maxHeight;

              final scrollOffset = ref.watch(chat_providers.chatScrollProvider);
              final maxScroll = ref.read(chat_providers.chatScrollProvider.notifier).maxScrollExtent;
              final panelHeight = screenHeight * _chatHeightFactor;
              const minBottom = _buttonBottomInset;
              final maxBottom = max(minBottom, panelHeight - _buttonSize);
              final range = max(1.0, maxBottom - minBottom);
              final fraction = maxScroll > 0 ? scrollOffset / maxScroll : 0.0;

              // Compute visual button position
              double chatButtonBottom;
              if (_isAnimatingClose) {
                // Move button down at same speed as panel, stop at original position
                chatButtonBottom = max(
                  _buttonBottomInset,
                  _buttonBottomBeforeClose - panelHeight * (1 - _chatSlideAnimation.value),
                );
                debugPrint('BUILD CLOSE: bottom=$chatButtonBottom, slide=${_chatSlideAnimation.value}');
              } else {
                if (_isChatOpen && !_isDraggingButton) {
                  _buttonBottom = minBottom + (1 - fraction) * range;
                }
                chatButtonBottom = _buttonBottom;
              }
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
                  AnimatedBuilder(
                    animation: _chatSlideAnimation,
                    builder: (context, child) {
                      final double panelHeight =
                          screenHeight * _chatHeightFactor;
                      final double offsetY = isChatEnabled
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

                  // Chat Panel (slides up from bottom) ------------------------------------------------
                  if (isChatEnabled)
                    Consumer(
                      builder: (context, ref, child) {
                        final messages = ref.watch(chat_providers.chatProvider);
                        return ChatPanel(
                          slideAnimation: _chatSlideAnimation,
                          theme: activeTheme,
                          heightFactor: _chatHeightFactor,
                          messages: messages,
                          onSendMessage: _sendChatMessage,
                          onHeightFactorChanged: (value) {
                            setState(() {
                              _chatHeightFactor = value;
                              final screenHeight = MediaQuery.of(context).size.height;
                              final panelHeight = screenHeight * _chatHeightFactor;
                              const minBottom = _buttonBottomInset;
                              final maxBottom = max(minBottom, panelHeight - _buttonSize);
                              _buttonBottom = _buttonBottom.clamp(minBottom, maxBottom);
                            });
                            final scrollNotifier = ref.read(chat_providers.chatScrollProvider.notifier);
                            final maxScroll = scrollNotifier.maxScrollExtent;
                            const minBottom = _buttonBottomInset;
                            final screenHeight = MediaQuery.of(context).size.height;
                            final panelHeight = screenHeight * value;
                            final maxBottom = max(minBottom, panelHeight - _buttonSize);
                            final range = max(1.0, maxBottom - minBottom);
                            final fraction = (_buttonBottom - minBottom) / range;
                            final targetOffset = (1 - fraction) * maxScroll;
                            scrollNotifier.setScrollOffset(targetOffset);
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
                  if (isChatEnabled)
                    Positioned(
                      bottom: chatButtonBottom,
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
                            child: child!,
                          );
                        },
                        child: GestureDetector(
                          onTap: _toggleChat,
                          onVerticalDragStart: !_isChatOpen
                              ? null
                              : (details) {
                                  setState(() {
                                    _isDraggingButton = true;
                                    _dragStartBottom = _buttonBottom;
                                    _dragStartDy = details.globalPosition.dy;
                                  });
                                },
                          onVerticalDragEnd: !_isChatOpen
                              ? null
                              : (details) {
                                  setState(() {
                                    _isDraggingButton = false;
                                  });
                                },
                          onVerticalDragUpdate: !_isChatOpen
                              ? null
                              : (details) {
                                final dragDelta = details.globalPosition.dy - _dragStartDy;
                                final newBottom = (_dragStartBottom - dragDelta)
                                  .clamp(minBottom, maxBottom);
                                final moved = newBottom - _buttonBottom;
                                if (moved == 0) {
                                  return;
                                }
                                setState(() {
                                  _buttonBottom = newBottom;
                                  _chatButtonDragAngle +=
                                    (moved / range) * (2 * pi * _rotationsPerPanel);
                                });
                                final fraction = (newBottom - minBottom) / range;
                                final targetOffset = (1 - fraction) * maxScroll;
                                ref.read(chat_providers.chatScrollProvider.notifier)
                                    .setScrollOffset(targetOffset);
                              },
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