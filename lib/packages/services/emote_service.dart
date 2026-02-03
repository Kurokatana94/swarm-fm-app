import 'package:dio/dio.dart';
import 'package:swarm_fm_app/packages/models/chat_models.dart';

class EmoteService {
  final Dio _dio = Dio();

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
      throw Exception('Failed to load 7TV emote set: $e');
    }
  }
}
