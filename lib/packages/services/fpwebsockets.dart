import 'dart:async';
import 'dart:convert';
import 'package:web_socket_client/web_socket_client.dart';

class FPWebsockets {
  late final WebSocket io;
  String userAgent;
  StreamSubscription? listen;
  StreamSubscription? listen2;
  bool authsent = false;

  FPWebsockets({required this.userAgent}) {
    io = WebSocket(
      Uri.parse('wss://player.sw.arm.fm/chat'),
      headers: {'User-Agent': userAgent, 'Origin': 'https://player.sw.arm.fm'},
    );
  }

  registerListener(Function(Map<String, dynamic>) messagesHandler) {
    if (listen != null) {
      listen!.cancel();
      listen = null;
    }
    if (listen2 != null) {
      listen2!.cancel();
      listen2 = null;
    }
    listen = io.messages.listen((message) {
      messagesHandler(jsonDecode(message));
    });
    listen2 = io.connection.listen((state) async {
      if (state.toString() == "Instance of 'Connected'") {
        if (authsent) {
          // Reconnection logic
        }
      }
    });
  }

  sendChatMessage(String message) async {
    if (message.isNotEmpty) {
      io.send(jsonEncode({"type": "send_message", "message": message}));
    }
  }

  historyRequest() async {
    bool connected = false;
    final stream = io.connection.listen((state) {
      if (state.toString() == "Instance of 'Connected'") {
        connected = true;
        io.send(jsonEncode({"type": "history_request"}));
      }
    });
    while (!connected) {
      await Future.delayed(const Duration(seconds: 1));
    }
    stream.cancel();
  }

  Future<String> authorise(String session) async {
    bool connected = false;
    bool authSent = false;
    StreamSubscription? msgstream;
    String name = '';
    bool nameset = false;
    bool authSuccessReceived = false;
    final stream = io.connection.listen((state) {
      if (state.toString() == "Instance of 'Connected'" && !authSent) {
        connected = true;
        msgstream = io.messages.listen((message) {
          final decoded = jsonDecode(message);
          print('🔐 Auth flow - received message: $decoded');
          
          // Handle auth_success response
          if (decoded['type'] == 'auth_success' && !nameset && decoded['name'] != null) {
            name = decoded['name'];
            nameset = true;
            authSuccessReceived = true;
            print('🔐 Auth - auth_success received with name: $name');
          }
          
          // Handle "Already authenticated" - session is still valid
          if (decoded['type'] == 'error' && decoded['message'] == 'Already authenticated' && !nameset) {
            print('🔐 Auth - Already authenticated (session still valid)');
            authSuccessReceived = true;
            // Don't set nameset yet, wait for user_join to get the actual username
          }
          
          // Wait for user_join
          if (decoded['type'] == 'user_join' && !nameset && decoded['name'] != null) {
            msgstream!.cancel();
            name = decoded['name'];
            nameset = true;
            print('🔐 Auth - user_join received with name: $name');
          }
        });
        final body = jsonEncode({"type": "authenticate", "session": session});
        print('🔐 Auth - sending authenticate message with session: $session');
        io.send(body);
        authSent = true;
        this.authsent = true;
      }
    });
    while (!connected) {
      await Future.delayed(const Duration(seconds: 1));
    }
    int namesetattempts = 0;
    // If we got "Already authenticated", we still need to wait for user_join to get the username
    // But if that doesn't come, we can return success after a shorter timeout
    while (!nameset && namesetattempts < 10) {
      await Future.delayed(const Duration(seconds: 1));
      namesetattempts++;
      // If we got auth_success or already_authenticated but no user_join after 3 seconds, something's wrong
      if (authSuccessReceived && namesetattempts > 3) {
        print('🔐 Auth - auth succeeded but no user_join received, continuing anyway');
        break;
      }
    }
    stream.cancel();
    msgstream?.cancel();
    print('🔐 Auth - authorise() returning name: "$name" (nameset=$nameset, authSuccess=$authSuccessReceived)');
    return name;
  }

  Future<List<dynamic>> getChatUserList() async {
    late List<dynamic> users;
    bool recieved = false;
    final listen = io.messages.listen((message) {
      final decoded = jsonDecode(message);
      if (decoded['type'] == 'user_list') {
        users = decoded['users'];
        recieved = true;
      }
    });
    io.send(jsonEncode({"type": "user_list"}));
    while (!recieved) {
      await Future.delayed(const Duration(seconds: 1));
    }
    listen.cancel();
    return users;
  }

  disconnect() {
    listen?.cancel();
    listen2?.cancel();
    io.close();
  }

  void resetAuthState() {
    authsent = false;
  }
}
