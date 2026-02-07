import 'package:flutter/material.dart';

extension StringCasingExtension on String {
  String get toCapitalized => length > 0 ?'${this[0].toUpperCase()}${substring(1).toLowerCase()}':'';
  String get toTitleCase => replaceAll(RegExp(' +'), ' ').split(' ').map((str) => str.toCapitalized).join(' ');
}

Color parseColorFromHex(String colorHex) {
  try {
    return Color(int.parse('0xFF${colorHex.replaceAll('#', '')}'));
  } catch (e) {
    return Colors.white;
  }
}