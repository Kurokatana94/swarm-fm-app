import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:url_launcher/url_launcher.dart';

class Credits extends StatelessWidget {
  Map theme;
  Credits({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Credits', textAlign: TextAlign.center, style: TextStyle(color: theme['settings_text'], fontSize: 24, fontWeight: FontWeight.bold,),), backgroundColor: theme['settings_bg'], centerTitle: true,),
      backgroundColor: theme['settings_bg'],
      body: Center(
        child: ListView(
          padding: EdgeInsets.all(10),
          children: [
            // Neuro and Evil Logos ------------------------------------------------
            Padding(
              padding: EdgeInsetsGeometry.all(10),
              child: Text('― Neuro-Sama & Evil-Neuro Logos ―', textAlign: TextAlign.center, style: TextStyle(color: theme['settings_text'], fontSize: 20),),
            ),
            
            // Frequence
            Padding(
              padding: EdgeInsetsGeometry.all(10),
                child: Text('fFrequence', textAlign: TextAlign.center, style: TextStyle(color: theme['settings_text'], fontSize: 18),),
            ),


            IconButton(onPressed: () {launchUrl(Uri.parse('https://x.com/Frequence_'));}, 
              icon: SvgPicture.asset('assets/images/icons/X_logo_2023_original.svg', width: 30, height: 30,),
            ),
            
            // Vedal
            Padding(
              padding: EdgeInsetsGeometry.all(10),
                child: Text('Vedal987', textAlign: TextAlign.center, style: TextStyle(color: theme['settings_text'], fontSize: 18),),
            ),

            IconButton(onPressed: () {launchUrl(Uri.parse('https://www.twitch.tv/vedal987'));}, 
              icon: SvgPicture.asset('assets/images/icons/twitch-tile.svg', width: 40, height: 40,),
            ),

            IconButton(onPressed: () {launchUrl(Uri.parse('https://vedal.ai/'));}, 
              icon: SvgPicture.asset('assets/images/icons/vedal.svg', width: 50, height: 50,),
            ),
            
            // SwarmFM ------------------------------------------------
            Padding(
              padding: EdgeInsetsGeometry.all(10),
                child: Text('― SwarmFM & SwarmFM Logo ―', textAlign: TextAlign.center, style: TextStyle(color: theme['settings_text'], fontSize: 20),),
            ),

            // boop
            Padding(
              padding: EdgeInsetsGeometry.all(10),
                child: Text('boop.', textAlign: TextAlign.center, style: TextStyle(color: theme['settings_text'], fontSize: 18),),
            ),

            IconButton(onPressed: () {launchUrl(Uri.parse('https://www.youtube.com/@boop'));}, 
              icon: SvgPicture.asset('assets/images/icons/youtube-svgrepo-com.svg', width: 40, height: 40,),
            ),

            IconButton(onPressed: () {launchUrl(Uri.parse('https://player.sw.arm.fm/'));}, 
              icon: SvgPicture.asset('assets/images/icons/swarm-fm-icon.svg', width: 50, height: 50,),
            ),

            // Vedal987 Logo and Source Code ------------------------------------------------ 
            Padding(
              padding: EdgeInsetsGeometry.all(10),
                child: Text('― Vedal987 Logo & Source Code ―', textAlign: TextAlign.center, style: TextStyle(color: theme['settings_text'], fontSize: 20),),
            ),

            // Kuro
            Padding(
              padding: EdgeInsetsGeometry.all(10),
                child: Text('Kurokatana94', textAlign: TextAlign.center, style: TextStyle(color: theme['settings_text'], fontSize: 18),),
            ),

            IconButton(onPressed: () {launchUrl(Uri.parse('https://github.com/Kurokatana94'));}, 
              icon: SvgPicture.asset('assets/images/icons/github-svgrepo-com.svg', width: 40, height: 40,),
            ),
          ],
        ),
      )
    );
  }
}