import 'package:flutter/material.dart';
import 'package:swarm_fm_app/main.dart';

class TwitchLoginInstructionsPopup extends StatelessWidget {
  const TwitchLoginInstructionsPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: activeTheme['settings_bg'],
      title: Text(
        'Twitch Login',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: activeTheme['settings_text'],
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To enable chat, you need to log in with Twitch:',
            style: TextStyle(fontWeight: FontWeight.bold, color: activeTheme['settings_text']),
          ),
          SizedBox(height: 16),
          Text('1. Click the Twitch login button in the web player',
            style: TextStyle(fontWeight: FontWeight.bold, color: activeTheme['settings_text']),
          ),
          SizedBox(height: 8),
          Text('2. Complete the Twitch authentication',
            style: TextStyle(fontWeight: FontWeight.bold, color: activeTheme['settings_text']),
          ),
          SizedBox(height: 8),
          Text('3. Press "Done" button at the top when finished',
            style: TextStyle(fontWeight: FontWeight.bold, color: activeTheme['settings_text']),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: activeTheme['settings_text']),
          ),
        ),
        ElevatedButton(
          style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(activeTheme['settings_bg']),
                    shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        side: BorderSide(color: activeTheme['settings_text']!, width: 2),
                      ),
                    ),
                  ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Continue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: activeTheme['settings_text']),
          ),
        ),
      ],
    );
  }
}