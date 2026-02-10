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
            final scrollController = ScrollController();
            
            final filteredEmotes = emotes.where((e) => e.url1x.contains(targetGroup)).toList();
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              color: activeTheme['chat_icon_fg'] ,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      // Define the buttons
                      segments: const [
                        ButtonSegment<String>(
                          value: 'jtvnw.net',
                          label: Text('Twitch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        ButtonSegment<String>(
                          value: '7tv.app',
                          label: Text('7TV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                      
                      // Logic to track which one is active
                      selected: {targetGroup},
                      
                      // What happens when you click
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          targetGroup = newSelection.first;
                        });
                        scrollController.jumpTo(0.0);
                      },

                      // Custom styling to match your theme
                      style: SegmentedButton.styleFrom(
                        backgroundColor: activeTheme['chat_icon_bg'],
                        foregroundColor: activeTheme['chat_icon_fg'], // Text color
                        selectedForegroundColor: activeTheme['chat_icon_bg'],        // Text color when active
                        selectedBackgroundColor: activeTheme['chat_icon_fg'], // Fill color when active
                        side: BorderSide(color: activeTheme['chat_icon_bg']!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _groupTwitchEmotesByOwner(filteredEmotes).length,
                      itemBuilder: (context, index) {
                        final entry = _groupTwitchEmotesByOwner(filteredEmotes).entries.elementAt(index);
                        final onwerName = entry.key;
                        final emotes = entry.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                "- $onwerName -",
                                style: TextStyle(
                                  color: activeTheme['chat_icon_bg'] ,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: emotes.length,
                              itemBuilder: (context, emoteIndex) {
                                final emote = emotes[emoteIndex] ;
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
                                          color: activeTheme['chat_icon_bg'],
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
                                                color: activeTheme['chat_icon_bg'] ,
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
                          ],
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

  Map<String, List> _groupTwitchEmotesByOwner(List<ChatEmote> emotes) {
    final Map<String, List<ChatEmote>> grouped = {};
    for (final emote in emotes) {
      grouped.putIfAbsent(emote.ownerName, () => []).add(emote);
    }

    return grouped;
  }
}