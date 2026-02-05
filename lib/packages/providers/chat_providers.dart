import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swarm_fm_app/packages/models/chat_models.dart';
import 'package:swarm_fm_app/packages/services/emote_service.dart';

// Emote Providers
final emoteServiceProvider = Provider((ref) => EmoteService());

final sevenTVEmotesProvider = FutureProvider<List<SevenTVEmote>>((ref) async {
  final emoteService = ref.watch(emoteServiceProvider);

  const emoteSets = {
    'vedal': "01GN2QZDS0000BKRM8E4JJD3NV",
    'swarmfm_whisper': "01JKCEZS0D4MGWVNGKQWBTWSYT",
    'swarmfm_emotes': "01JKCF444J7HTNKE4TEQ0DBP1F",
  };

  final allEmotes = <SevenTVEmote>[];

  for (final emoteSetId in emoteSets.values) {
    try {
      final emotes = await emoteService.getSevenTVEmoteSet(emoteSetId);
      allEmotes.addAll(emotes);
    } catch (e) {
      print('Error loading emote set: $e');
    }
  }

  return allEmotes;
});

// Chat Providers
class ChatManager extends StateNotifier<List<ChatMessage>> {
  ChatManager(this.ref) : super([]);
  final Ref ref;

  void addMessage(ChatMessage message) {
    final newState = [...state, message];
    state = newState.length > 175
        ? newState.sublist(newState.length - 175)
        : newState;
  }

  void removeMessage(int id) {
    state = state.where((message) => message.id != id).toList();
  }

  void strikeMessage(int id) {
    state = [
      for (final message in state)
        if (message.id == id)
          message.copyWith(isStruckThrough: true)
        else
          message,
    ];
  }

  void reset() {
    state = [];
  }
}

final chatProvider = StateNotifierProvider<ChatManager, List<ChatMessage>>((
  ref,
  ) {
  return ChatManager(ref);
});

// Connection Status
class ConnectionManager extends StateNotifier<Map<String, dynamic>> {
  ConnectionManager(this.ref) : super({});
  final Ref ref;

  void updateConnectionState(Map<String, dynamic> data) {
    if (data['color'] == 'success') {
      Future.delayed(const Duration(seconds: 7), () {
        reset();
      });
    }
    state = data;
  }

  void reset() {
    state = {};
  }
}

final connectionProvider =
    StateNotifierProvider<ConnectionManager, Map<String, dynamic>>((ref) {
      return ConnectionManager(ref);
    });

// Ban/Timeout Providers
final timeoutProvider = StateNotifierProvider<TimeoutManager, Timeout>((ref) {
  return TimeoutManager(ref);
});

class TimeoutManager extends StateNotifier<Timeout> {
  TimeoutManager(this.ref) : super(Timeout(timeoutTime: DateTime.now()));
  final Ref ref;

  void timeout(DateTime timeoutTime) {
    state = Timeout(timeoutTime: timeoutTime);
  }
}

final banProvider = StateProvider<bool>((ref) => false);

// Chat broken (scrolled up state)
final chatbroken = StateProvider<bool>((ref) => false);

// Error State
class ErrorState {
  final bool hasError;
  final String errorMessage;

  ErrorState({this.hasError = false, this.errorMessage = ''});
}

class ErrorNotifier extends StateNotifier<ErrorState> {
  ErrorNotifier() : super(ErrorState());

  void setError(String message) {
    state = ErrorState(hasError: true, errorMessage: message);
  }

  void clearError() {
    state = ErrorState();
  }
}

final errorProvider = StateNotifierProvider<ErrorNotifier, ErrorState>((ref) {
  return ErrorNotifier();
});
