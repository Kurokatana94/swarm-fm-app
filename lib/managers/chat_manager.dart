import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../packages/models/chat_models.dart';

class ChatManager {
  final _secureStorage = const FlutterSecureStorage();

  static const String _sessionStorageKey = 'swarm_chat_session';
  static const String _userIdStorageKey = 'swarm_chat_user_id';
  // static const String _chatServerUrl = 'wss://player.sw.arm.fm/chat';
  static const int _maxMessages = 100;

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

  // Generate a new session ID
  String generateSessionId() {
    return const Uuid().v4();
  }

  // Save session token
  Future<void> saveSession(sessionToken) async {
    await _secureStorage.write(key: _sessionStorageKey, value: sessionToken);
  }

  // Fetch session token
  Future<String?> fetchSession() async {
    return await _secureStorage.read(key: _sessionStorageKey);
  }

  // Save user ID
  Future<void> saveUserId(userId) async {
    await _secureStorage.write(key: _userIdStorageKey, value: userId);
  }

  // Fetch user ID
  Future<String?> fetchUserId() async {
    return await _secureStorage.read(key: _userIdStorageKey);
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _sessionStorageKey);
    await _secureStorage.delete(key: _userIdStorageKey);
  }

  Future<bool> isLoggedIn() async {
    final session = await fetchSession();
    return session != null && session.isNotEmpty;
  }

  // Add a new message to the chat
  void addMessage(ChatMessage message) {
    _messages.add(message);
    // Keep only the last _maxMessages messages
    if (_messages.length > _maxMessages) {
      _messages.removeRange(0, _messages.length - _maxMessages);
    }
    _messagesStreamController.add(List.unmodifiable(_messages));
  }

  // Load messages from the server (mock for now)
  Future<void> loadInitialMessages() async {
    // This would normally fetch from the WebSocket connection
    // or from a REST API endpoint
    _connectionStreamController.add(true);
    _messagesStreamController.add(List.unmodifiable(_messages));
  }

  // Clear all messages
  void clearMessages() {
    _messages.clear();
    _messagesStreamController.add(List.unmodifiable(_messages));
  }

  void dispose() {
    _messagesStreamController.close();
    _connectionStreamController.close();
  }
}