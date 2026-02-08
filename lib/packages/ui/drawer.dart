import 'package:flutter/material.dart';
import 'package:swarm_fm_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swarm_fm_app/packages/popups/twitch_login_inappwebview.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:swarm_fm_app/packages/popups/twitch_login_instructions.dart';
import 'package:swarm_fm_app/packages/ui/credits.dart';
import 'package:swarm_fm_app/managers/chat_manager.dart';
import 'package:swarm_fm_app/packages/providers/websocket_provider.dart';
import 'package:swarm_fm_app/packages/providers/chat_login_provider.dart';
import 'package:swarm_fm_app/packages/providers/theme_provider.dart';
import 'package:swarm_fm_app/packages/providers/chat_providers.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {

  final ChatManager _chatManager = ChatManager();
  bool _isLoggingIn = false;
  
  @override
  void initState() {
    super.initState();
    print('👤 [LOGIN FLOW] AppDrawer initState - loading chat login state...');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatLoginProvider.notifier).loadLoginState();
    });
  }

  Future<void> _loginWithSessionToken(String sessionToken) async {
    print('👤 [LOGIN FLOW] _loginWithSessionToken() called with token length: ${sessionToken.length}');
    print('=== MANUAL SESSION LOGIN ===');
    print('Session token: $sessionToken');

    try {
      setState(() => _isLoggingIn = true);
      print('👤 [LOGIN FLOW] Saving session to ChatManager...');
      await _chatManager.saveSession(sessionToken);
      print('👤 [LOGIN FLOW] Session saved');
      
      final fpWebsockets = ref.read(fpWebsocketsProvider);
      print('👤 [LOGIN FLOW] Got fpWebsockets provider');

      print('👤 [LOGIN FLOW] Calling authorize() with session...');
      final username = await fpWebsockets.authorise(sessionToken).timeout(
        const Duration(seconds: 15), // Increased from 10 to 15 seconds for "Already authenticated" case
        onTimeout: () {
          print('👤 [LOGIN FLOW] Authorization timed out after 15 seconds');
          return '';
        },
      );
      print('👤 [LOGIN FLOW] Authorize returned - Username: "$username"');

      if (mounted) {
        if (username.isNotEmpty) {
          print('👤 [LOGIN FLOW] Username is not empty, saving username and updating state...');
          await _chatManager.saveUsername(username);
          ref.read(chatLoginProvider.notifier).setLoggedIn(true);
          setState(() {
            _isLoggingIn = false;
          });
          print('👤 [LOGIN FLOW] ✅ LOGIN SUCCESSFUL - User: $username');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logged in as $username'),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // Session token auth succeeded (no user_join received, likely "Already authenticated")
          // The session is valid even if we couldn't get the username from WebSocket
          print('👤 [LOGIN FLOW] ⚠️ No username from WebSocket, but session appears valid - setting logged in = true');
          ref.read(chatLoginProvider.notifier).setLoggedIn(true);
          setState(() => _isLoggingIn = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logged in with existing session'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoggingIn = false);
      print('👤 [LOGIN FLOW] ❌ ERROR in _loginWithSessionToken: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleChatLogin() async {
    print('👤 [LOGIN FLOW] _handleChatLogin() started');
    if (!mounted) return;

    // No existing session, show instructions then launch Twitch login popup
    if (!mounted) return;
    
    print('👤 [LOGIN FLOW] Showing login instructions popup...');
    final shouldProceedPopup = await showDialog<bool>(
      context: context,
      builder: (context) => const TwitchLoginInstructionsPopup()
    );

    if (shouldProceedPopup != true || !mounted) {
      print('👤 [LOGIN FLOW] User cancelled instructions popup');
      return;
    }
    
    print('👤 [LOGIN FLOW] Showing Twitch login popup...');
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const TwitchLoginPopup(),
    );

    print('👤 [LOGIN FLOW] Twitch login popup returned: $result');

    // Handle the result from the popup
    if (result == true || result is String) {
      print('👤 [LOGIN FLOW] Login popup returned: $result');
      
      // If we got a username directly from the webview, use it
      if (result is String && result.isNotEmpty) {
        print('👤 [LOGIN FLOW] Got username from webview: $result');
        final session = await _chatManager.fetchSession();
        if (session != null && session.isNotEmpty) {
          // Ensure websocket auth is performed even if username was extracted.
          await _loginWithSessionToken(session);
        }
      } else {
        // Fallback to WebSocket authentication if no username from webview
        print('👤 [LOGIN FLOW] Login popup returned true, fetching session from storage...');
        final session = await _chatManager.fetchSession();
        print('👤 [LOGIN FLOW] Fetched session from storage: ${session != null ? 'exists' : 'null'}');
        if (session != null && session.isNotEmpty) {
          print('👤 [LOGIN FLOW] Session is valid, calling _loginWithSessionToken()');
          await _loginWithSessionToken(session);
        } else {
          print('👤 [LOGIN FLOW] Session is empty or null');
        }
      }
    } else {
      // User closed webview without logging in or login failed
      print('👤 [LOGIN FLOW] User closed webview or login failed - clearing all cookies and tokens');
      final cookieManager = CookieManager.instance();
      try {
        await cookieManager.deleteAllCookies();
        print('👤 [LOGIN FLOW] All cookies cleared');
      } catch (e) {
        print('👤 [LOGIN FLOW] Error clearing cookies: $e');
      }
      // Clear session from ChatManager as well
      await _chatManager.clearSession();
      setState(() => _isLoggingIn = false);
    }
  }

  Future<void> _handleChatLogout() async {
    final cookieManager = CookieManager.instance();
    try {
      await cookieManager.deleteAllCookies();
    } catch (e) {
      print('Error clearing cookies: $e');
    }
    await ref.read(chatLoginProvider.notifier).logout();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final activeTheme = themeState.theme;

    final isChatEnabled = ref.watch(isChatEnabledProvider);
    
    return Drawer(
      backgroundColor: activeTheme['settings_bg'],
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding:  EdgeInsets.only(top: 40, bottom: 20), 
            child: Text('Settings', style: TextStyle(color: activeTheme['settings_title'], fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),

          Text('― Themes ―', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),

          // Theme selection options ------------------------------------------------ 
          // Neuro Theme
          ListTile(
            leading: IgnorePointer(
              child: Switch(
                value: themeState.themeName == 'neuro',
                inactiveThumbColor: activeTheme['settings_text'],
                activeThumbColor: activeTheme['settings_bg'],
                activeTrackColor: activeTheme['settings_text'],
                inactiveTrackColor: activeTheme['settings_bg'],
                onChanged: (_) {}
              ),
            ),
            title: Text('Neuro', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
            onTap: () {
              ref.read(themeProvider.notifier).changeTheme('neuro');
            },
          ),

          // Evil Theme
          ListTile(
            leading: IgnorePointer(
              child: Switch(
                value: themeState.themeName == 'evil',
                inactiveThumbColor: activeTheme['settings_text'],
                activeThumbColor: activeTheme['settings_bg'],
                activeTrackColor: activeTheme['settings_text'],
                inactiveTrackColor: activeTheme['settings_bg'],
                onChanged: (_) {}
              ),
            ),
            title: Text('Evil', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
            onTap: () {
              ref.read(themeProvider.notifier).changeTheme('evil');
            },
          ),

          // Vedal Theme
          ListTile(
            leading: IgnorePointer(
              child: Switch(
                value: themeState.themeName == 'vedal',
                inactiveThumbColor: activeTheme['settings_text'],
                activeThumbColor: activeTheme['settings_bg'],
                activeTrackColor: activeTheme['settings_text'],
                inactiveTrackColor: activeTheme['settings_bg'],
                onChanged: (_) {}
              ),
            ),
            title: Text('Vedal', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
            onTap: () {
              ref.read(themeProvider.notifier).changeTheme('vedal');
            },
          ),

          Text('― Audio Service ―', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),

          ListTile(
            leading: IgnorePointer(
              child: Switch(
                value: activeAudioService == "HLS",
                inactiveThumbColor: activeTheme['settings_text'],
                activeThumbColor: activeTheme['settings_bg'],
                activeTrackColor: activeTheme['settings_text'],
                inactiveTrackColor: activeTheme['settings_bg'],
                onChanged: (_) {}
              ),
            ),
            title: Text('HLS', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
            onTap: () {
              setState(() {
                activeAudioService = "HLS";
                saveAudioServiceState(activeAudioService);
              });
            },
          ),

          ListTile(
            leading: IgnorePointer(
              child: Switch(
                value: activeAudioService == "SHUFFLE",
                inactiveThumbColor: activeTheme['settings_text'],
                activeThumbColor: activeTheme['settings_bg'],
                activeTrackColor: activeTheme['settings_text'],
                inactiveTrackColor: activeTheme['settings_bg'],
                onChanged: (_) {}
              ),
            ),
            title: Text('Shuffle', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
            onTap: () {
              setState(() {
                activeAudioService = "SHUFFLE";
                saveAudioServiceState(activeAudioService);
              });
            },
          ),
          
          Text('― Chat ―', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
          
          // Twitch Chat Options ------------------------------------------------
          ListTile(
            leading: Switch(
              value: isChatEnabled,
              inactiveThumbColor: activeTheme['settings_text'],
              activeThumbColor: activeTheme['settings_bg'],
              activeTrackColor: activeTheme['settings_text'],
              inactiveTrackColor: activeTheme['settings_bg'],
              onChanged: (_) {
                ref.read(isChatEnabledProvider.notifier).toggleChat();
              }
            ),
            // TODO FIX
            title: Text(isChatEnabled ? 'On' : 'Off', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
            trailing: _isLoggingIn
              ? SizedBox(
                  width: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(activeTheme['settings_text']),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Opacity(
                        opacity: 0.5,
                        child: Text(
                          'Login',
                          style: TextStyle(fontWeight: FontWeight.w600, color: activeTheme['settings_text']),
                        ),
                      ),
                    ],
                  ),
                )
              : Consumer(
                  builder: (context, ref, child) {
                    final isLoggedIn = ref.watch(chatLoginProvider);
                    return TextButton(
                      onPressed: isLoggedIn ? _handleChatLogout : _handleChatLogin,
                      style: TextButton.styleFrom(
                        foregroundColor: activeTheme['settings_text'],
                      ),
                      child: Text(
                        isLoggedIn ? 'Logout' : 'Login',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                ),
          ),

          Text('― Info ―', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),

          // Credits page ------------------------------------------------
          ListTile(
            leading: Icon(Icons.info, color: activeTheme['settings_text'],),
            title: Text('Credits', style: TextStyle(color: activeTheme['settings_text'], fontSize: 18)),
            onTap: () {
              Navigator.push(context, MaterialPageRoute<void>(builder: (context) => Credits(theme: activeTheme)));
            },
          ),
        ],
      ),
    );
  }
}