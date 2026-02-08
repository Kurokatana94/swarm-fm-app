import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swarm_fm_app/packages/models/chat_models.dart';
import 'package:swarm_fm_app/packages/services/emote_service.dart';
import 'package:swarm_fm_app/managers/chat_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Emote Providers
final emoteServiceProvider = Provider((ref) => EmoteService());

final sevenTVEmotesProvider = FutureProvider<List<ChatEmote>>((ref) async {
  final emoteService = ref.watch(emoteServiceProvider);
  final chatManager = ChatManager();

  const twitchChannelIds = <int>[
    85498365, // vedal987
    56418014, // annytf
    469632185, // camila
    825937345, // Ellie_Minibot
    852880224, // cerberVT
    1004060561, // MinikoMew
    32173571, // chrchie
    99728740, // alexvoid
    64140092, // LaynaLazar
    542237669, // toma
  ];

  const emoteSets = {
    'vedal': "01GN2QZDS0000BKRM8E4JJD3NV",
    'swarmfm_whisper': "01JKCEZS0D4MGWVNGKQWBTWSYT",
    'swarmfm_emotes': "01JKCF444J7HTNKE4TEQ0DBP1F",
  };

  final mergedEmotes = <String, ChatEmote>{};

  const twitchClientId = String.fromEnvironment('TWITCH_CLIENT_ID', defaultValue: '');
  const twitchClientSecret = String.fromEnvironment('TWITCH_CLIENT_SECRET', defaultValue: '');

  if (twitchClientId.isNotEmpty && twitchClientSecret.isNotEmpty) {
    try {
      final appToken = await emoteService.getTwitchAppAccessToken(
        twitchClientId,
        twitchClientSecret,
      );

      final globalEmotes = await emoteService.getTwitchGlobalEmotes(
        twitchClientId,
        appToken,
      );
      for (final emote in globalEmotes) {
        mergedEmotes[emote.name] = emote;
      }

      for (final channelId in twitchChannelIds) {
        final channelEmotes = await emoteService.getTwitchChannelEmotes(
          twitchClientId,
          appToken,
          channelId,
        );
        for (final emote in channelEmotes) {
          mergedEmotes[emote.name] = emote;
        }
      }
    } catch (e) {
      print('Error loading Twitch app emotes: $e');
    }
  }

  final session = await chatManager.fetchSession();
  if (session != null && session.isNotEmpty) {
    try {
      final twitchEmotes = await emoteService.getTwitchUserEmotes(session);
      for (final emote in twitchEmotes) {
        mergedEmotes[emote.name] = emote;
      }
    } catch (e) {
      print('Error loading Twitch user emotes: $e');
    }
  }

  for (final emoteSetId in emoteSets.values) {
    try {
      final emotes = await emoteService.getSevenTVEmoteSet(emoteSetId);
      for (final emote in emotes) {
        mergedEmotes[emote.name] = ChatEmote.fromSevenTV(emote);
      }
    } catch (e) {
      print('Error loading emote set: $e');
    }
  }

  return mergedEmotes.values.toList();
});

// Chat Providers
class ChatStateManager extends StateNotifier<List<ChatMessage>> {
  ChatStateManager(this.ref) : super([]);
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

final chatProvider = StateNotifierProvider<ChatStateManager, List<ChatMessage>>((
  ref,
  ) {
  return ChatStateManager(ref);
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

// Chat Enabled State with async loading
class ChatEnabledNotifier extends StateNotifier<bool> {
  ChatEnabledNotifier() : super(true) {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('isChatEnabled') ?? true;
  }

  Future<void> toggleChat() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isChatEnabled', state);
  }
}

final isChatEnabledProvider = StateNotifierProvider<ChatEnabledNotifier, bool>((ref) {
  return ChatEnabledNotifier();
});

final connectionProvider = StateNotifierProvider<ConnectionManager, Map<String, dynamic>>((ref) {
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

