import 'package:flutter/material.dart';

const int nameColorCount = 10;

const List<String> liveChatUsernameColors = [
  'AAAAAA',
  '006699',
  'CC6600',
  'D400D4',
  '009933',
  'FF6600',
  '006666',
  'B63D3D',
  '9763CB',
  '0099CC',
];

int getUsernameColorIndex(String username) {
  final usernameHash = fastHashStringToInt(username);
  return (usernameHash % nameColorCount);
}

const int _maxSafeInteger = 9007199254740991;

int fastHashStringToInt(String str) {
  BigInt hashCode = BigInt.zero;

  for (var i = 0; i < str.length; i++) {
    final codeUnit = str.codeUnitAt(i);
    hashCode = BigInt.from(codeUnit) + ((hashCode << 5) - hashCode);
  }

  BigInt safeHashCode = hashCode % BigInt.from(_maxSafeInteger);

  if (safeHashCode.bitLength > 63) {
    throw RangeError('Hash value exceeds the range of an int');
  }

  return safeHashCode.toInt();
}

String getColorForUsername(String username) {
  int colorIndex = getUsernameColorIndex(username);
  return liveChatUsernameColors[colorIndex];
}

Color getColorForUsernameColor(String username) {
  String colorHex = getColorForUsername(username);
  Color color = Color(int.parse('0xFF$colorHex'));
  return color;
}

Color parseColorFromHex(String colorHex) {
  try {
    return Color(int.parse('0xFF${colorHex.replaceAll('#', '')}'));
  } catch (e) {
    return Colors.white;
  }
}
