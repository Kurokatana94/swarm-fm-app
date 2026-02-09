import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_models.dart';
import '../providers/theme_provider.dart';

class EmotesSelector extends ConsumerStatefulWidget {
  final TextEditingController _messageController;
  final FocusNode _messageFocusNode;
  final List<ChatEmote> _emotes;

  EmotesSelector({
    super.key,
    required TextEditingController messageController,
    required FocusNode messageFocusNode,
    required List<ChatEmote> emotes,
  }) : _messageController = messageController,
       _messageFocusNode = messageFocusNode,
       _emotes = emotes;
  
  @override
  ConsumerState<EmotesSelector> createState() => _EmotesSelectorState();
}

class _EmotesSelectorState extends ConsumerState<EmotesSelector> {
  String targetGroup = 'jtvnw.net'; // Default to Twitch emotes

  // TODO - Separate emotes into groups (Twitch, 7TV, etc) to allow filtering in picker and sort by account provider
  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final theme = themeState.theme;

    return IconButton(
      icon: const Icon(Icons.emoji_emotions_outlined),
      color: theme['chat_icon_bg'],
      tooltip: 'Pick emote',
      onPressed: () => _showEmoteSelector(context, widget._emotes),
    );
  }

  void _showEmoteSelector(BuildContext context, List<ChatEmote> emotes) {  
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final themeState = ref.watch(themeProvider);
            final activeTheme = themeState.theme;
            
            // Filter emotes by search query
            final filteredEmotes = emotes.where((e) => e.url1x.contains(targetGroup)).toList();
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              color: activeTheme['chat_icon_fg'],
              child: Column(
                children: [
                  // Emote group selector
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              targetGroup = 'jtvnw.net';
                            });
                          },
                          child: Text('Twitch', style: TextStyle(color: activeTheme['chat_icon_bg'])),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              targetGroup = '7tv.app';
                            });
                          },
                          child: Text('7TV', style: TextStyle(color: activeTheme['chat_icon_bg'])),
                        )
                      ],
                    )
                  ),
                  const SizedBox(height: 8),
                  // Emote grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: filteredEmotes.length,
                      itemBuilder: (context, index) {
                        final emote = filteredEmotes[index];
                        return GestureDetector(
                          onTap: () {
                            widget._messageController.text += '${emote.name} ';
                            Navigator.pop(context);
                            widget._messageFocusNode.requestFocus();
                          },
                          child: Tooltip(
                            message: emote.name,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: activeTheme['chat_icon_bg']!.withOpacity(0.3),
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Image.network(
                                emote.url2x,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) {
                                  return Center(
                                    child: Text(
                                      '?',
                                      style: TextStyle(
                                        color: activeTheme['chat_icon_bg'],
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _groupEmoteBySource(ChatEmote emote) {
    // Infer group from URL or name
    if (emote.url1x.contains('7tv.app')) {
      return '7TV';
    } else if (emote.url1x.contains('jtvnw.net')) {
      print('Twitch emote detected: (${emote.url1x})');
      return 'Twitch';
    }
    return 'Other';
  }
}