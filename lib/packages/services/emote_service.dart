import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:swarm_fm_app/packages/models/chat_models.dart';

class EmoteService {
  final Dio _dio = Dio();

  String _formatDioError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode?.toString() ?? 'unknown';
      final data = error.response?.data?.toString() ?? 'no response body';
      return 'status=$status body=$data';
    }
    return error.toString();
  }

  ChatEmote _mapTwitchHelixEmote(
    Map<String, dynamic> json,
    String template,
  ) {
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
      return template
          .replaceAll('{{id}}', id)
          .replaceAll('{{format}}', format)
          .replaceAll('{{theme_mode}}', theme)
          .replaceAll('{{scale}}', scale);
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

  Future<List<SevenTVEmote>> getSevenTVEmoteSet(String emoteSetId) async {
    const gql = r'''
      query EmoteSet($emoteSetId: ObjectID!, $formats: [ImageFormat!]) {
        emoteSet(id: $emoteSetId) {
          emotes {
            id
            name
            data {
              animated
              flags
              host {
                files(formats: $formats) {
                  height
                  width
                }
              }
            }
          }
        }
      }
    ''';

    try {
      final response = await _dio.post(
        'https://7tv.io/v3/gql',
        data: {
          'operationName': 'EmoteSet',
          'query': gql,
          'variables': {
            'emoteSetId': emoteSetId,
            'formats': ['AVIF'],
          },
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> emotesData =
            response.data['data']['emoteSet']['emotes'];
        return emotesData.map((emoteJson) {
          return SevenTVEmote.fromJson(
            emoteJson,
            emoteJson['data']['host']['files'],
          );
        }).toList();
      } else {
        throw Exception('Failed to load 7TV emote set');
      }
    } catch (e) {
      throw Exception('Failed to load 7TV emote set: ${_formatDioError(e)}');
    }
  }

  Future<List<ChatEmote>> getTwitchUserEmotes(String sessionToken) async {
    try {
      final response = await _dio.get(
        'https://player.sw.arm.fm/twitch_user_emotes',
        options: Options(
          headers: {
            'Cookie': 'swarm_fm_player_session=$sessionToken',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load Twitch user emotes');
      }

      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      if (data is! Map) {
        throw Exception('Unexpected Twitch emotes response');
      }



      return data.values
          .whereType<Map>()
          .map((emoteJson) => ChatEmote.fromTwitchUserEmote(
                Map<String, dynamic>.from(emoteJson),
              ))
          .where((emote) => emote.name.isNotEmpty)
          .toList();
    } catch (e) {
      throw Exception('Failed to load Twitch user emotes: ${_formatDioError(e)}');
    }
  }

  Future<String> getTwitchAppAccessToken(
    String clientId,
    String clientSecret,
  ) async {
    try {
      final response = await _dio.post(
        'https://id.twitch.tv/oauth2/token',
        data: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'client_credentials',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get Twitch app token');
      }

      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      if (data is! Map || data['access_token'] == null) {
        throw Exception('Unexpected Twitch token response');
      }

      return data['access_token'].toString();
    } catch (e) {
      throw Exception('Failed to get Twitch app token: ${_formatDioError(e)}');
    }
  }

  Future<List<ChatEmote>> getTwitchGlobalEmotes(
    String clientId,
    String accessToken,
  ) async {
    try {
      final response = await _dio.get(
        'https://api.twitch.tv/helix/chat/emotes/global',
        options: Options(
          headers: {
            'Client-Id': clientId,
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load Twitch global emotes');
      }

      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      if (data is! Map || data['data'] is! List || data['template'] == null) {
        throw Exception('Unexpected Twitch global emotes response');
      }

      final template = data['template'].toString();
      final List<dynamic> emotesData = data['data'] as List<dynamic>;

      return emotesData
          .whereType<Map>()
          .map((emoteJson) => _mapTwitchHelixEmote(
                Map<String, dynamic>.from(emoteJson),
                template,
              ))
          .where((emote) => emote.name.isNotEmpty)
          .toList();
    } catch (e) {
      throw Exception('Failed to load Twitch global emotes: ${_formatDioError(e)}');
    }
  }

  Future<List<ChatEmote>> getTwitchChannelEmotes(
    String clientId,
    String accessToken,
    int broadcasterId,
  ) async {
    try {
      final response = await _dio.get(
        'https://api.twitch.tv/helix/chat/emotes',
        queryParameters: {
          'broadcaster_id': broadcasterId,
        },
        options: Options(
          headers: {
            'Client-Id': clientId,
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load Twitch channel emotes');
      }

      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      if (data is! Map || data['data'] is! List || data['template'] == null) {
        throw Exception('Unexpected Twitch channel emotes response');
      }

      final template = data['template'].toString();
      final List<dynamic> emotesData = data['data'] as List<dynamic>;

      return emotesData
          .whereType<Map>()
          .map((emoteJson) => _mapTwitchHelixEmote(
                Map<String, dynamic>.from(emoteJson),
                template,
              ))
          .where((emote) => emote.name.isNotEmpty)
          .toList();
    } catch (e) {
      throw Exception('Failed to load Twitch channel emotes: ${_formatDioError(e)}');
    }
  }
}
