import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../packages/models/chat_models.dart';

class ChatManager {
  final _secureStorage = const FlutterSecureStorage();

  static const String _sessionStorageKey = 'swarm_chat_session';
  static const String _userIdStorageKey = 'swarm_chat_user_id';
  static const String _usernameStorageKey = 'twitch_username';
  static const String _accessTokenStorageKey = 'twitch_access_token';

  static final ChatManager _instance = ChatManager._internal();
  factory ChatManager() => _instance;
  ChatManager._internal();

  // Message stream and storage
  final List<ChatMessage> _messages = [];
  final _messagesStreamController = StreamController<List<ChatMessage>>.broadcast();
  final _connectionStreamController = StreamController<bool>.broadcast();

  Stream<List<ChatMessage>> get messagesStream => _messagesStreamController.stream;
  Stream<bool> get connectionStream => _connectionStreamController.stream;
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  // Save session token
  Future<void> saveSession(sessionToken) async {
    await _secureStorage.write(key: _sessionStorageKey, value: sessionToken);
  }

  // Fetch session token
  Future<String?> fetchSession() async {
    return await _secureStorage.read(key: _sessionStorageKey);
  }

  // Save Twitch username
  Future<void> saveUsername(String username) async {
    await _secureStorage.write(key: _usernameStorageKey, value: username);
  }

  // Fetch Twitch username
  Future<String?> fetchUsername() async {
    return await _secureStorage.read(key: _usernameStorageKey);
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _sessionStorageKey);
    await _secureStorage.delete(key: _userIdStorageKey);
    await _secureStorage.delete(key: _usernameStorageKey);
    await _secureStorage.delete(key: _accessTokenStorageKey);
  }
  void dispose() {
    _messagesStreamController.close();
    _connectionStreamController.close();
  }
}