import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:swarm_fm_app/managers/audio_handler.dart';
import 'package:swarm_fm_app/packages/main_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swarm_fm_app/themes/themes.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lock_orientation_screen/lock_orientation_screen.dart';
import 'package:swarm_fm_app/packages/services/fpwebsockets.dart';
import 'package:swarm_fm_app/packages/providers/websocket_provider.dart';

Map activeTheme = themes['neuro'];

bool isNeuroTheme = true;
bool isEvilTheme = false;
bool isVedalTheme = false;

String activeAudioService = "HLS";

bool isHls = true;
bool isShuffle = false;

late AudioHandler audioHandler;
late FPWebsockets fpWebsockets;

// Main process init------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.kurokatana94.swarmfm.channel.audio',
      androidNotificationChannelName: 'Swarm FM',
      androidNotificationIcon: "drawable/swarm_fm_icon",
      androidShowNotificationBadge: true,
      androidNotificationOngoing: true,
      androidNotificationClickStartsActivity: true,
    ),
  );

  // Initialize WebSocket
  final packageInfo = await PackageInfo.fromPlatform();
  final userAgent = 'SwarmFMApp/${packageInfo.version} (${packageInfo.buildNumber})';
  fpWebsockets = FPWebsockets(userAgent: userAgent);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  var status = await Permission.notification.status;
  if (status.isDenied) {
    await Permission.notification.request();
  }

  await loadThemeState();
  
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool? isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

  runApp(MyApp(isFirstLaunch: isFirstLaunch,));
}

// App init ------------------------------------------------
class MyApp extends StatelessWidget {
  final bool isFirstLaunch;
  const MyApp({super.key, required this.isFirstLaunch});
  
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: LockOrientation( 
        child: MaterialApp(
          title: 'Swarm FM Player',
          theme: ThemeData(fontFamily: 'First Coffee'),
          debugShowCheckedModeBanner: false,
          home: SwarmFMPlayerPage(isFirstLaunch: isFirstLaunch,),
        )
      ),
    );
  }
}

class MediaState {
  final MediaItem? mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}

// Text outline formatter ------------------------------------------------
List<Text> outlineFormatter(String text, int outlineWidth, Color outlineColor, Color fillColor, double fontSize) {
  List<Text> outlines = [];
  for (int x = -outlineWidth; x <= outlineWidth; x++) {
    for (int y = -outlineWidth; y <= outlineWidth; y++) {
      if (x == 0 && y == 0) continue;
      outlines.add(
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Sobiscuit',
            fontSize: fontSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = outlineColor,
          ),
        ),
      );
    }
  }
  outlines.add(
    Text(
      text,
      style: TextStyle(
        fontFamily: 'Sobiscuit',
        fontSize: fontSize,
        color: fillColor,
      ),
    ),
  );
  return outlines;
}

// Function to change the active theme ------------------------------------------------
void changeTheme(String themeName) {
  if (themes.containsKey(themeName)) {
    activeTheme = themes[themeName];
  }
}

// It simply returns the active stream url, but in future might change depending on how the system evolves ------------------------------------------------
String getStreamUrl() {
  final randomInt = Random().nextInt(1047) + 1;
  return activeAudioService == "HLS" ? 'https://stream.sw.arm.fm/new/hls_audio.m3u8' : 'https://swarmfm.boopdev.com/assets/music/$randomInt.mp3';
}

// Themes saving ------------------------------------------------
Future<void> saveThemeState(String themeName, bool isNeuro, bool isEvil, bool isVedal) async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString('activeTheme', themeName);
  await prefs.setBool('isNeuroTheme', isNeuro);
  await prefs.setBool('isEvilTheme', isEvil);
  await prefs.setBool('isVedalTheme', isVedal);
}

// Theme loading ------------------------------------------------
Future<void> loadThemeState() async {
  final prefs = await SharedPreferences.getInstance();

  String themeName = prefs.getString('activeTheme') ?? 'neuro';

  isNeuroTheme = prefs.getBool('isNeuroTheme') ?? true;
  isEvilTheme = prefs.getBool('isEvilTheme') ?? false;
  isVedalTheme = prefs.getBool('isVedalTheme') ?? false;

  activeTheme = themes[themeName];
}
