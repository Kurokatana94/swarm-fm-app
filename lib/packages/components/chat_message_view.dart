import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_models.dart';
import '../providers/chat_providers.dart';
import '../../utils/general_utils.dart';

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
    List<ChatEmote> emoteList,
  ) {
    final emotes = {for (var e in emoteList) e.name: e};
    final List<InlineSpan> spans = [];
    final words = message.message.split(' ');
    final List<InlineSpan> textSpans = [];
    final tokenRegex = RegExp(r'^([^A-Za-z0-9_]*)([A-Za-z0-9_]+)([^A-Za-z0-9_]*)$');

    String _extractCore(String token) {
      final match = tokenRegex.firstMatch(token);
      if (match == null) return token;
      return match.group(2) ?? token;
    }

    void _addTextSpan(String text) {
      if (text.isEmpty) return;
      textSpans.add(
        TextSpan(
          text: text,
          style: message.isStruckThrough
              ? TextStyle(decoration: TextDecoration.lineThrough, color: textColor)
              : TextStyle(color: textColor),
        ),
      );
    }

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final coreWord = _extractCore(word);
      final emote = emotes[coreWord];

      if (emote != null && !emote.zeroWidth) {
        // This is a base emote, check for subsequent zero-width emotes
        final List<ChatEmote> zeroWidthEmotes = [];
        int j = i + 1;
        while (j < words.length) {
          final nextWord = words[j];
          final nextCore = _extractCore(nextWord);
          final nextEmote = emotes[nextCore];
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
              emote.url2x,
              height: emoteHeight,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Image.network(
                  emote.url1x,
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
                zeroWidthEmote.url2x,
                height: emoteHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Image.network(
                    zeroWidthEmote.url1x,
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

        final match = tokenRegex.firstMatch(word);
        final leading = match?.group(1) ?? '';
        final trailing = match?.group(3) ?? '';

        _addTextSpan(leading);
        textSpans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Stack(alignment: Alignment.center, children: stackChildren),
          ),
        );
        _addTextSpan(trailing);
        _addTextSpan(' ');

        i = j - 1; // Move index past the consumed zero-width emotes
      } else if (emote != null && emote.zeroWidth) {
        // Standalone zero-width emote, render as text
        _addTextSpan('$word ');
      } else {
        // Regular word
        _addTextSpan('$word ');
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
                ? TextStyle(decoration: TextDecoration.lineThrough, fontWeight: FontWeight.bold, color: displayColor)
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
