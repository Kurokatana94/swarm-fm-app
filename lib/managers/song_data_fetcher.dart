import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SongData {
  final String id;
  final String name;
  final String artist;
  final List<dynamic> singer;
  final int duration;

  SongData({
    required this.id,
    required this.name,
    required this.artist,
    required this.singer,
    required this.duration,
  });
  
  factory SongData.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    if (current is Map<String, dynamic>) {
      json = current;
    }

    return SongData(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Swarm FM',
      artist: json['artist'] ?? '',
      singer: json['singer'] ?? [],
      duration: json['duration'] ?? 20,
    );
  }
}

Future<SongData> fetchSongData() async {
  final response = await http.get(Uri.parse("https://swarmfm.boopdev.com/v2/player"));

  if (response.statusCode == 200) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    await _addSongDataToLocalStorage(body);
    return SongData.fromJson(body);
  } else {
    throw Exception('Failed to load song data');
  }
}

// Adds a new json entry to the local storage jsonl file, for shuffle
Future<void> _addSongDataToLocalStorage(Map<String, dynamic> songsJson) async {
  final dir = await getApplicationDocumentsDirectory();
  final dataDir = Directory('${dir.path}/data');
  if (!await dataDir.exists()) {
    await dataDir.create(recursive: true);
  }
  final file = File('${dataDir.path}/songs_data.jsonl');

  final existingIds = await _getExistingSongIds(file);

  final fectchedSongs = [
    songsJson['previous'],
    songsJson['current'],
    songsJson['next'],
  ].whereType<Map<String, dynamic>>();

  final lines = <String>[];

  for (final song in fectchedSongs) {
    final id = song['id']?.toString();
    if (id != null && !existingIds.contains(id)) {
      print('!!!!!! New song data fetched: ${song['name']} by ${song['artist']} (ID: $id) !!!!!!');
      if (song['id'].length < 5) {
        print('!!!!!! Skipping song with broken ID !!!!!!');
        continue;
      }
      lines.add(jsonEncode(song));
      print('!!!!!! Adding new song data to local storage: ${song['name']} by ${song['artist']} (ID: $id) !!!!!!');
      existingIds.add(id);
    }
  }

  if (lines.isNotEmpty) {
    await file.writeAsString(
      '${lines.join('\n')}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}

Future<Set<String>> _getExistingSongIds(File file) async {
  if (!await file.exists()) return {};

  try {
    final lines = await file.readAsLines();
    final ids = <String>{};

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final id = json['id']?.toString();
        if (id != null) ids.add(id);
      } catch (_) {}
    }

    return ids;
  } catch (_) {
    return {};
  }
}

Future<List<Map<String, dynamic>>> loadLocalMetadata() async {
  final dir = await getApplicationDocumentsDirectory();
  final dataDir = Directory('${dir.path}/data');
  if (!await dataDir.exists()) {
    await dataDir.create(recursive: true);
  }
  final file = File('${dataDir.path}/songs_data.jsonl');

  String content;

  if (!await file.exists()) {
    content = await rootBundle.loadString('assets/data/songs_data.jsonl');
    await file.writeAsString(content, flush: true);
    print('!!!!!! Local metadata file created with bundled data. !!!!!!');
  } else {
    content = await file.readAsString();
  }

  return LineSplitter.split(content)
      .where((line) => line.trim().isNotEmpty)
      .map((line) {
        try {
          return jsonDecode(line) as Map<String, dynamic>;
        } catch (_) {
          return <String, dynamic>{};
        }
      })
      .where((map) => map.isNotEmpty)
      .toList();
}