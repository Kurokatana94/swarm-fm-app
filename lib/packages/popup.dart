import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';


Future<void> showBatterySettingsPopup(context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(
      child: AlertDialog(
        title: Center(
          child: Text(
            '⚠️ Important ⚠️',
            style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
            ),
          )
        ),
        content: Text(
          'To ensure the app works properly in the background, please disable battery optimization.', 
          style: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isFirstLaunch', false);
              await openBatteryOptimizationSettings();

              // Closes the window
              Navigator.of(context).pop();
            },
            child: Center(
              child: Text(
                  'OK',
                  style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ),
        ],
      ),
    ),
  );
}

Future<void> openBatteryOptimizationSettings() async {
  final intent = AndroidIntent(
    action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
    data: 'package:com.kurokatana94.swarmfm.channel.audio',
    flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
  );
  await intent.launch();
}