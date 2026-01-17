import 'dart:convert';
import 'package:http/http.dart' as http;

class SongData {
  final String title;
  final String artist;
  final List<dynamic> singers;

  SongData({
    required this.title,
    required this.artist,
    required this.singers,
  });
  
  factory SongData.fromJson(Map<String, dynamic> json) {
    json = json["current"];

    return SongData(
      title: json['name'] ?? 'Swarm FM',
      artist: json['artist'] ?? '',
      singers: json['singer'] ?? '',
    );
  }
}

Future<SongData> fetchSongData() async {
  final response = await http.get(Uri.parse("https://swarmfm.boopdev.com/v2/player"));

  if (response.statusCode == 200) {
    return SongData.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load song data');
  }
}