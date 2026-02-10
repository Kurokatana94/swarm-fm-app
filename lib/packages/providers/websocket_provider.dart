import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swarm_fm_app/main.dart';
import 'package:swarm_fm_app/packages/models/chat_models.dart';
import 'package:swarm_fm_app/packages/providers/chat_providers.dart';
import 'package:swarm_fm_app/packages/services/fpwebsockets.dart';

// WebSocket instance provider - returns the global fpWebsockets instance
final fpWebsocketsProvider = Provider<FPWebsockets>((ref) {
  return fpWebsockets;
});

// WebSocket event handler
final webSocketEventHandlerProvider = Provider<WebSocketEventHandler>((ref) {
  return WebSocketEventHandler(ref);
});

class WebSocketEventHandler {
  final Ref ref;

  WebSocketEventHandler(this.ref);

  void messagesHandler(Map<String, dynamic> data) async {
    if (data['type'] == 'new_message') {
      final msg = data['message'];
      final message = ChatMessage(
        name: msg['name'],
        nameColor: msg['name_color'] ?? 'FFFFFF',
        message: msg['message'],
        id: msg['id'],
      );
      ref.read(chatProvider.notifier).addMessage(message);
    } else if (data['type'] == 'message_history') {
      final msgs = data['messages'] ?? [];
      for (final msg in msgs) {
        final message = ChatMessage(
          name: msg['name'],
          nameColor: msg['name_color'] ?? 'FFFFFF',
          message: msg['message'],
          id: msg['id'],
        );
        ref.read(chatProvider.notifier).addMessage(message);
      }
    } else if (data['type'] == 'user_timed_out') {
      if (data['name'] != null) {
        final timeoutTime = DateTime.now().add(
          Duration(seconds: data['duration'] ?? 0),
        );
        ref.read(timeoutProvider.notifier).timeout(timeoutTime);
      }
    } else if (data['type'] == 'user_banned') {
      if (data['name'] != null) {
        ref.read(banProvider.notifier).state = true;
      }
    } else if (data['type'] == 'message_deleted') {
      ref.read(chatProvider.notifier).removeMessage(data['id']);
    }
  }

  void connectionHandler(Map<String, dynamic> data) {
    ref.read(connectionProvider.notifier).updateConnectionState(data);
  }
}
