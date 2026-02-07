import 'package:flutter/foundation.dart';

@immutable
class ChatMessage {
  final String? name;
  final String nameColor;
  final String message;
  final int id;
  final bool isStruckThrough;

  const ChatMessage({
    this.name,
    required this.nameColor,
    required this.message,
    required this.id,
    this.isStruckThrough = false,
  });

  ChatMessage copyWith({
    String? name,
    String? nameColor,
    String? message,
    int? id,
    bool? isStruckThrough,
  }) {
    return ChatMessage(
      name: name ?? this.name,
      nameColor: nameColor ?? this.nameColor,
      message: message ?? this.message,
      id: id ?? this.id,
      isStruckThrough: isStruckThrough ?? this.isStruckThrough,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      name: json['name'],
      nameColor: json['name_color'] ?? 'FFFFFF',
      message: json['message'] ?? '',
      id: json['id'] ?? 0,
      isStruckThrough: json['is_struck_through'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'name_color': nameColor,
      'message': message,
      'id': id,
      'is_struck_through': isStruckThrough,
    };
  }
}

class SevenTVEmote {
  final String id;
  final String name;
  final int flags;
  final bool animated;
  final String url;
  final int height;
  final int width;

  bool get zeroWidth => flags != 0;

  const SevenTVEmote({
    required this.id,
    required this.name,
    required this.flags,
    required this.animated,
    required this.url,
    required this.height,
    required this.width,
  });

  factory SevenTVEmote.fromJson(
    Map<String, dynamic> json,
    List<dynamic> files,
  ) {
    return SevenTVEmote(
      id: json['id'],
      name: json['name'],
      animated: json['data']['animated'] ?? false,
      flags: json['data']['flags'] ?? 0,
      url: 'https://cdn.7tv.app/emote/${json['id']}',
      width: files[0]['width'] ?? 32,
      height: files[0]['height'] ?? 32,
    );
  }
}

class ChatEmote {
  final String name;
  final String url1x;
  final String url2x;
  final int width;
  final int height;
  final bool zeroWidth;

  const ChatEmote({
    required this.name,
    required this.url1x,
    required this.url2x,
    required this.width,
    required this.height,
    required this.zeroWidth,
  });

  factory ChatEmote.fromSevenTV(SevenTVEmote emote) {
    return ChatEmote(
      name: emote.name,
      url1x: '${emote.url}/1x.webp',
      url2x: '${emote.url}/2x.webp',
      width: emote.width,
      height: emote.height,
      zeroWidth: emote.zeroWidth,
    );
  }

  factory ChatEmote.fromTwitchUserEmote(Map<String, dynamic> json) {
    final formats = (json['format'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final scales = (json['scale'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final themes = (json['theme_mode'] as List?)?.map((e) => e.toString()).toList() ?? const [];

    final format = formats.contains('animated') ? 'animated' : 'static';
    final theme = themes.contains('light') ? 'light' : (themes.isNotEmpty ? themes.first : 'dark');
    final scale1x = scales.contains('1.0') ? '1.0' : (scales.isNotEmpty ? scales.first : '1.0');
    final scale2x = scales.contains('2.0') ? '2.0' : (scales.isNotEmpty ? scales.last : scale1x);

    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';

    String buildUrl(String scale) {
      return 'https://static-cdn.jtvnw.net/emoticons/v2/$id/$format/$theme/$scale';
    }

    return ChatEmote(
      name: name,
      url1x: buildUrl(scale1x),
      url2x: buildUrl(scale2x),
      width: 28,
      height: 28,
      zeroWidth: false,
    );
  }
}

class Timeout {
  final DateTime timeoutTime;

  Timeout({required this.timeoutTime});
}
