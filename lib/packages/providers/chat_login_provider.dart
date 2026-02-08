import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swarm_fm_app/managers/chat_manager.dart';
import 'package:swarm_fm_app/packages/providers/websocket_provider.dart';

// Chat login state notifier
class ChatLoginNotifier extends StateNotifier<bool> {
  final Ref ref;
  final ChatManager _chatManager = ChatManager();
  bool _isInitialized = false;

  ChatLoginNotifier(this.ref) : super(false);

  // Load and validate session on initialization (only once)
  Future<void> loadLoginState() async {
    if (_isInitialized) {
      print('👤 [LOGIN STATE] Already initialized, skipping loadLoginState()');
      return;
    }
    _isInitialized = true;
    
    print('👤 [LOGIN STATE] loadLoginState() checking if already logged in...');
    final session = await _chatManager.fetchSession();
    
    if (session != null && session.isNotEmpty) {
      print('👤 [LOGIN STATE] Found session, validating with server...');
      try {
        final fpWebsockets = ref.read(fpWebsocketsProvider);
        final username = await fpWebsockets.authorise(session).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('👤 [LOGIN STATE] Session validation timed out');
            return '';
          },
        );
        
        if (username.isNotEmpty) {
          print('👤 [LOGIN STATE] Session is valid, user: $username');
          await _chatManager.saveUsername(username);
          state = true;
        } else {
          print('👤 [LOGIN STATE] Session validation failed (empty username), clearing session');
          await _chatManager.clearSession();
          state = false;
        }
      } catch (e) {
        print('👤 [LOGIN STATE] Error validating session: $e');
        await _chatManager.clearSession();
        state = false;
      }
    } else {
      print('👤 [LOGIN STATE] No session found');
      state = false;
    }
  }

  // Set logged in state
  void setLoggedIn(bool value) {
    state = value;
  }

  // Clear login state and session
  Future<void> logout() async {
    print('👤 [LOGIN STATE] logout() called - clearing session and resetting auth state');
    print('👤 [LOGIN STATE] Stack trace: ${StackTrace.current}');
    await _chatManager.clearSession();
    final fpWebsockets = ref.read(fpWebsocketsProvider);
    fpWebsockets.resetAuthState();
    state = false;
    print('👤 [LOGIN STATE] logout() completed - user is now logged out');
  }
}

// Provider for chat login state
final chatLoginProvider = StateNotifierProvider<ChatLoginNotifier, bool>((ref) {
  return ChatLoginNotifier(ref);
});
