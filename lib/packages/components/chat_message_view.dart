import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_models.dart';
import '../providers/chat_providers.dart';
import '../utils/chat_utils.dart';

class ChatMessageView extends ConsumerWidget {
  final ChatMessage message;
  final Color textColor;
  final Color backgroundColor;

  const ChatMessageView({
    super.key,
    required this.message,
    required this.textColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emotesAsyncValue = ref.watch(sevenTVEmotesProvider);

    return emotesAsyncValue.when(
      data: (emotes) => _buildMessageWithEmotes(context, emotes),
      loading: () => _buildPlainMessage(),
      error: (err, stack) => _buildPlainMessage(),
    );
  }

  Widget _buildMessageWithEmotes(
    BuildContext context,
    List<SevenTVEmote> emoteList,
  ) {
    final emotes = {for (var e in emoteList) e.name: e};
    final List<InlineSpan> spans = [];
    final words = message.message.split(' ');
    final List<InlineSpan> textSpans = [];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final emote = emotes[word];

      if (emote != null && !emote.zeroWidth) {
        // This is a base emote, check for subsequent zero-width emotes
        final List<SevenTVEmote> zeroWidthEmotes = [];
        int j = i + 1;
        while (j < words.length) {
          final nextWord = words[j];
          final nextEmote = emotes[nextWord];
          if (nextEmote != null && nextEmote.zeroWidth) {
            zeroWidthEmotes.add(nextEmote);
            j++;
          } else {
            break;
          }
        }

        final allEmotes = [emote, ...zeroWidthEmotes];

        // Calculate the maximum width needed for proper stacking
        const double emoteHeight = 28.0;
        final double maxWidth = allEmotes
            .map((e) => (e.width / e.height) * emoteHeight)
            .reduce((a, b) => a > b ? a : b);

        final List<Widget> stackChildren = [];

        // Add base emote first (bottom of stack)
        stackChildren.add(
          SizedBox(
            width: maxWidth,
            height: emoteHeight,
            child: Image.network(
              '${emote.url}/2x.webp',
              height: emoteHeight,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Image.network(
                  '${emote.url}/1x.webp',
                  height: emoteHeight,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return SizedBox.shrink();
                  },
                );
              },
            ),
          ),
        );

        // Add zero-width emotes on top
        for (final zeroWidthEmote in zeroWidthEmotes) {
          stackChildren.add(
            SizedBox(
              width: maxWidth,
              height: emoteHeight,
              child: Image.network(
                '${zeroWidthEmote.url}/2x.webp',
                height: emoteHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Image.network(
                    '${zeroWidthEmote.url}/1x.webp',
                    height: emoteHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
          );
        }

        textSpans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Stack(alignment: Alignment.center, children: stackChildren),
          ),
        );

        i = j - 1; // Move index past the consumed zero-width emotes
      } else if (emote != null && emote.zeroWidth) {
        // Standalone zero-width emote, render as text
        textSpans.add(
          TextSpan(
            text: '$word ',
            style: message.isStruckThrough
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
        );
      } else {
        // Regular word
        textSpans.add(
          TextSpan(
            text: '$word ',
            style: message.isStruckThrough
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
        );
      }
    }

    spans.addAll(textSpans);

    final displayColor = message.nameColor.isNotEmpty
        ? parseColorFromHex(message.nameColor)
        : textColor;

    final richText = RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(
            text: message.name == null ? '' : '${message.name}: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: displayColor,
            ),
          ),
          TextSpan(
            style: message.isStruckThrough
                ? const TextStyle(decoration: TextDecoration.lineThrough, fontWeight: FontWeight.bold,)
                : null,
            children: spans,
          ),
        ],
      ),
    );

    return richText;
  }

  Widget _buildPlainMessage() {
    final displayColor = message.nameColor.isNotEmpty
        ? parseColorFromHex(message.nameColor)
        : textColor;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${message.name}: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: displayColor,
            ),
          ),
          TextSpan(
            text: message.message,
            style: TextStyle(
              decoration: message.isStruckThrough
                  ? TextDecoration.lineThrough
                  : null,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
