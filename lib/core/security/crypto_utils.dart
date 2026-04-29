import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class CryptoUtils {
  CryptoUtils._();

  static String generateSalt({int length = 16}) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64UrlEncode(bytes);
  }

  static String hashPin(String pin, String salt) {
    final normalizedPin = pin.trim();
    final bytes = utf8.encode('$salt:$normalizedPin');
    return sha256.convert(bytes).toString();
  }
}

