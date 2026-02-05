import 'dart:async';
import 'package:flutter/material.dart';
import 'package:swarm_fm_app/managers/chat_manager.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:swarm_fm_app/main.dart';

class TwitchLoginPopup extends StatefulWidget {
  const TwitchLoginPopup({super.key});

  @override
  State<TwitchLoginPopup> createState() => _TwitchLoginPopupState();
}

class _TwitchLoginPopupState extends State<TwitchLoginPopup> {
  final ChatManager _chatManager = ChatManager();

  Future<void> _handleDone() async {
    try {
      final cookieManager = CookieManager.instance();
      final cookies = await cookieManager.getCookies(
        url: WebUri('https://player.sw.arm.fm'),
      );

      final sessionCookie = cookies.firstWhere(
        (cookie) => cookie.name == 'swarm_fm_player_session',
        orElse: () => Cookie(name: ''),
      );

      if (sessionCookie.name.isNotEmpty) {
        print('Session cookie found: ${sessionCookie.value}');
        await _chatManager.saveSession(sessionCookie.value);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No session found. Please try logging in first.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error getting cookie: $e');
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: activeTheme['settings_bg'],
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.95,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Title
                Expanded(
                  child: Text(
                    'Swarm FM Player - Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: activeTheme['settings_text']),
                  ),
                ),
                // Done button
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
                  onPressed: _handleDone,
                  child: Text(
                    'Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: activeTheme['settings_text']),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // WebView
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://player.sw.arm.fm/'),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                thirdPartyCookiesEnabled: true,
                userAgent: 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
              ),
              onLoadStart: (controller, url) {
                print('Loading: $url');
              },
              onLoadStop: (controller, url) {
                print('Loaded: $url');
              },
            ),
          ),
        ],
      ),
    );
  }
}