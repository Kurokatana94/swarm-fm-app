import 'dart:async';
import 'package:flutter/material.dart';
import 'package:swarm_fm_app/managers/chat_manager.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class TwitchLoginPopup extends StatefulWidget {
  const TwitchLoginPopup({super.key});

  @override
  _TwitchLoginPopupState createState() => _TwitchLoginPopupState();
}

class _TwitchLoginPopupState extends State<TwitchLoginPopup> {
  final ChatManager _chatManager = ChatManager();
  InAppWebViewController? _webViewController;

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
                const Expanded(
                  child: Text(
                    'Swarm FM Player - Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _handleDone,
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
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