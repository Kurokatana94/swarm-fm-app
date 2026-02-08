import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:swarm_fm_app/packages/components/chat_message_view.dart';
import '../models/chat_models.dart';
import 'package:swarm_fm_app/packages/providers/theme_provider.dart';
import 'package:swarm_fm_app/packages/providers/chat_providers.dart';
import 'package:swarm_fm_app/packages/providers/chat_login_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatPanel extends ConsumerStatefulWidget {
  final Animation<double> slideAnimation;
  final Map<dynamic, dynamic> theme;
  final double heightFactor;
  final ValueChanged<double> onHeightFactorChanged;
  final ValueChanged<double>? onDragDelta;
  final List<ChatMessage> messages;
  final Function(String)? onSendMessage;

  const ChatPanel({
    super.key,
    required this.slideAnimation,
    required this.theme,
    required this.heightFactor,
    required this.onHeightFactorChanged,
    this.onDragDelta,
    this.messages = const [],
    this.onSendMessage,
  });

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  double _lastHeight = 0;
  late ScrollController _scrollController;
  late TextEditingController _messageController;
  late FocusNode _messageFocusNode;
  bool _isScrolledUp = false;
  bool _wasHidden = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _messageController = TextEditingController();
    _messageFocusNode = FocusNode();
    _scrollController.addListener(_onScrollChange);
    widget.slideAnimation.addListener(_handleSlideAnimation);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChange);
    _scrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    widget.slideAnimation.removeListener(_handleSlideAnimation);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slideAnimation != widget.slideAnimation) {
      oldWidget.slideAnimation.removeListener(_handleSlideAnimation);
      widget.slideAnimation.addListener(_handleSlideAnimation);
    }

    if (widget.messages.length != oldWidget.messages.length && !_isScrolledUp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToBottom();
      });
    }
  }

  void _onScrollChange() {
    // Check if user is scrolled up (not at bottom)
    if (_scrollController.hasClients) {
      final isAtBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50;
      setState(() {
        _isScrolledUp = !isAtBottom;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _jumpToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _handleSlideAnimation() {
    final isHidden = widget.slideAnimation.value == 0;
    if (_wasHidden && !isHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToBottom();
      });
    }
    _wasHidden = isHidden;
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty && widget.onSendMessage != null) {
      widget.onSendMessage!(text);
      _messageController.clear();
    }
  }

  void _showEmotePicker(BuildContext context, List<ChatEmote> emotes) {
    // Group emotes by channel (infer from URL or name patterns)
    final grouped = <String, List<ChatEmote>>{};
    for (final emote in emotes) {
      final group = _groupEmoteBySource(emote);
      grouped.putIfAbsent(group, () => []).add(emote);
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        final themeState = ref.watch(themeProvider);
        final activeTheme = themeState.theme;
        
        return Container(
          color: activeTheme['chat_icon_fg'],
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Emote',
                  style: TextStyle(
                    color: activeTheme['chat_icon_bg'],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: grouped.entries.map((entry) {
                    return ExpansionTile(
                      title: Text(
                        entry.key,
                        style: TextStyle(
                          color: activeTheme['chat_icon_bg'],
                        ),
                      ),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: entry.value.map((emote) {
                            return GestureDetector(
                              onTap: () {
                                _messageController.text += '${emote.name} ';
                                Navigator.pop(context);
                                _messageFocusNode.requestFocus();
                              },
                              child: Tooltip(
                                message: emote.name,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: activeTheme['chat_icon_bg']!,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Image.network(
                                    emote.url2x,
                                    width: 32,
                                    height: 32,
                                    errorBuilder: (context, error, stack) {
                                      return SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: Center(
                                          child: Text(
                                            '?',
                                            style: TextStyle(
                                              color: activeTheme['chat_icon_bg'],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _groupEmoteBySource(ChatEmote emote) {
    // Infer group from URL or name
    if (emote.url1x.contains('7tv.app')) {
      return '7TV';
    } else if (emote.url1x.contains('jtvnw.net')) {
      return 'Twitch';
    }
    return 'Other';
  }

  void _onDragUpdate(DragUpdateDetails details, double screenHeight) {
    // Map pointer position directly to panel height so the grabber follows
    // the finger/cursor without lag.
    final double newHeight = (screenHeight - details.globalPosition.dy)
        .clamp(screenHeight * 0.2, screenHeight * (4/7));
    final double next = newHeight / screenHeight;
    widget.onHeightFactorChanged(next);
    
    // Only emit drag delta if height actually changed (not clamped at limits)
    final double heightChange = newHeight - _lastHeight;
    if (heightChange != 0) {
      widget.onDragDelta?.call(-details.delta.dy / screenHeight);
      _lastHeight = newHeight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final activeTheme = themeState.theme;
    
    final isUserLoggedIn = ref.watch(chatLoginProvider);

    return AnimatedBuilder(
      animation: widget.slideAnimation,
      builder: (context, child) {
        final screenHeight = MediaQuery.of(context).size.height;
        final panelHeight = screenHeight * widget.heightFactor;
        
        // Initialize _lastHeight on first build
        if (_lastHeight == 0) {
          _lastHeight = panelHeight;
        }
        
        // Slide from bottom using animation value (0 = hidden, 1 = fully visible)
        final offset = panelHeight * (1 - widget.slideAnimation.value);

        final double rackWidth = 20.0;

        return Positioned(
          bottom: -offset,
          left: 0,
          right: 0,
          height: panelHeight,
          child: Container(
            color: null,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    // Grabber (drag to resize)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) =>
                          _onDragUpdate(details, screenHeight),
                      child: Container(
                        height: 18,
                        alignment: Alignment.center,
                        color: activeTheme['chat_icon_fg'],
                        child: Column( 
                          children: [
                            Padding(padding:  const EdgeInsets.only(top:4)),
                            Container(
                              width: 48,
                              height: 4,
                              decoration: BoxDecoration(
                                color: activeTheme['chat_icon_bg'],
                                borderRadius: BorderRadius.circular(4),
                                ),
                            ),
                            Padding(padding:  const EdgeInsets.only(top:4)),
                            Container(
                              width: 48,
                              height: 4,
                              decoration: BoxDecoration(
                                color: activeTheme['chat_icon_bg'],
                                borderRadius: BorderRadius.circular(4),
                                ),
                            ),
                          ]
                        ),
                      )
                    ),

                    // Chat messages area with scrolling
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            color: activeTheme['chat_icon_fg'],
                            child: widget.messages.isEmpty
                                ? Center(
                                    child: Text(
                                      'No messages yet',
                                      style: TextStyle(
                                        color: activeTheme['chat_icon_bg']
                                            ?.withOpacity(0.5),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(12),
                                    itemCount: widget.messages.length,
                                    itemBuilder: (context, index) {
                                      final message = widget.messages[index];

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: ChatMessageView(
                                          message: message,
                                          textColor: activeTheme['chat_icon_bg']!,
                                          backgroundColor: activeTheme['chat_icon_fg']!,)
                                      );
                                    },
                                  ),
                          ),

                          // "Go to Latest Messages" button
                          if (_isScrolledUp)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _scrollToBottom,
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: activeTheme['chat_icon_bg']
                                        ?.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  margin: const EdgeInsets.all(8),
                                  child: Text(
                                    'New Messages',
                                    style: TextStyle(
                                      color: activeTheme['chat_icon_fg'],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Input container (bottom)
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 24, 80, 12),
                      color: activeTheme['chat_icon_fg'],
                      child: TextField(
                        readOnly: !isUserLoggedIn,
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        style: TextStyle(
                          color: activeTheme['chat_icon_bg'],
                        ),
                        decoration: InputDecoration(
                          hintText: !isUserLoggedIn ? 'Login to send messages' : 'Send a message',
                          hintStyle: TextStyle(
                            color: activeTheme['chat_icon_bg']?.withOpacity(0.7),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: activeTheme['chat_icon_bg'],
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: activeTheme['chat_icon_bg'],
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: activeTheme['chat_icon_bg'],
                              width: 3,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          // Emoji button as suffix icon
                          suffixIcon: Focus(
                            canRequestFocus: false,
                            skipTraversal: true,
                            child: IconButton(
                              onPressed: () {
                                final emotesAsyncValue = ref.read(sevenTVEmotesProvider);
                                emotesAsyncValue.whenData((emotes) {
                                  _showEmotePicker(context, emotes);
                                });
                              },
                              icon: Icon(
                                Icons.emoji_emotions_outlined,
                                color: activeTheme['chat_icon_bg'],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Right-side decorative SVG placeholder (attach your asset here)
                Positioned(
                  right: -rackWidth*.25,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        width: rackWidth,
                        'assets/images/gear-rack-chat.svg',
                        colorFilter: ColorFilter.mode(
                          activeTheme['chat_icon_bg']!,
                          BlendMode.srcIn,
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -20),
                        child: SvgPicture.asset(
                          width: rackWidth,
                          'assets/images/gear-rack-chat.svg',
                          colorFilter: ColorFilter.mode(
                            activeTheme['chat_icon_bg']!,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -40),
                        child: SvgPicture.asset(
                          width: rackWidth,
                          'assets/images/gear-rack-chat.svg',
                          colorFilter: ColorFilter.mode(
                            activeTheme['chat_icon_bg']!,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
