import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:swarm_fm_app/managers/chat_manager.dart';

class TwitchLoginPopup extends StatefulWidget {
  const TwitchLoginPopup({super.key});

  @override
  _TwitchLoginPopupState createState() => _TwitchLoginPopupState();
}

class _TwitchLoginPopupState extends State<TwitchLoginPopup> {
  final ChatManager _chatManager = ChatManager();
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    _sessionId = _chatManager.generateSessionId();

    await _cookieManager.setCookie(
      WebViewCookie(
        name: 'swarm_fm_player_session',
        value: _sessionId!,
        domain: 'player.sw.arm.fm',
        path: '/',
      ),
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (url) async {
            if (mounted) {
              setState(() => _isLoading = false);
            }

            if (url.startsWith('https://player.sw.arm.fm/')) {
              // NOTE: webview_flutter doesn't expose cookie reads reliably.
              // For now, we store the session we set before OAuth.
              // If this doesn't authenticate correctly, we can switch
              // to flutter_inappwebview for direct cookie access.
              if (_sessionId != null) {
                await _chatManager.saveSession(_sessionId!);
              }
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            }
          },
        ),
      )
      ..loadRequest(
        Uri.parse(
          'https://id.twitch.tv/oauth2/authorize?'
          'client_id=ijg6o5dv2nq9j6g4tcm6mx3p25twbz&'
          'redirect_uri=https://player.sw.arm.fm/twitch_auth&'
          'response_type=code&'
          'scope=',
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * .8,
        maxHeight: MediaQuery.of(context).size.height * .6,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Login with Twitch',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}