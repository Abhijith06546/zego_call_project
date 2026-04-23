import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class ZegoTokenHelper {
  static String generateToken04({
    required int appId,
    required String userId,
    required String appSign,
    int expireInSeconds = 3600,
    String payload = '',
  }) {
    final nonce = Random().nextInt(0x7FFFFFFF);
    final ctime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expire = ctime + expireInSeconds;

    final payloadJson = jsonEncode({
      'app_id': appId,
      'user_id': userId,
      'nonce': nonce,
      'ctime': ctime,
      'expire': expire,
      'payload': payload,
    });

    final keyBytes = _hexToBytes(appSign);
    final hmac = Hmac(sha256, keyBytes);
    final hashBytes = Uint8List.fromList(hmac.convert(utf8.encode(payloadJson)).bytes);
    final payloadBytes = utf8.encode(payloadJson);

    final buf = ByteData(4 + 2 + 32 + 4 + payloadBytes.length);
    int off = 0;
    buf.setUint32(off, 4, Endian.little); off += 4;
    buf.setUint16(off, 32, Endian.big); off += 2;
    for (int i = 0; i < 32; i++) { buf.setUint8(off + i, hashBytes[i]); }
    off += 32;
    buf.setUint32(off, payloadBytes.length, Endian.big); off += 4;
    for (int i = 0; i < payloadBytes.length; i++) { buf.setUint8(off + i, payloadBytes[i]); }

    return '04${base64.encode(buf.buffer.asUint8List())}';
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
