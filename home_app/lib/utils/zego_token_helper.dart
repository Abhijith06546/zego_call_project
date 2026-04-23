import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Generates a Zego Token04 using AES-128-CBC encryption.
///
/// Binary format: [version:2 BE][expire:4 BE][nonce_hi:4 BE][nonce_lo:4 BE][bodyLen:2 BE][iv:16][ciphertext]
/// AES-128 key  = MD5( raw 32-byte secret decoded from hex AppSign )
String generateZegoToken04({
  required int appId,
  required String userId,
  required String appSignHex,
  required String roomId,
  int expireSeconds = 3600,
}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final nonce = Random.secure().nextInt(0x7fffffff);
  final expire = now + expireSeconds;

  final payloadJson = jsonEncode({
    'app_id': appId,
    'user_id': userId,
    'nonce': nonce,
    'ctime': now,
    'expire': expire,
    'payload': roomId.isNotEmpty ? jsonEncode({'room_id': roomId}) : '',
  });

  // Decode 64-hex-char AppSign → 32 raw bytes → MD5 → 16-byte AES-128 key
  final secretBytes = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    secretBytes[i] = int.parse(appSignHex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  final keyBytes = Uint8List.fromList(md5.convert(secretBytes).bytes);

  final key = enc.Key(keyBytes);
  final iv = enc.IV.fromSecureRandom(16);
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  final encrypted = encrypter.encryptBytes(utf8.encode(payloadJson), iv: iv);

  // body = iv(16) + ciphertext
  final body = Uint8List(16 + encrypted.bytes.length);
  body.setRange(0, 16, iv.bytes);
  body.setRange(16, body.length, encrypted.bytes);

  // 16-byte binary header
  final header = ByteData(16);
  header.setUint16(0, 4, Endian.big);                    // version = 4
  header.setUint32(2, expire, Endian.big);               // expire timestamp
  header.setInt32(6, 0, Endian.big);                     // nonce high 32 bits (always 0)
  header.setInt32(10, nonce, Endian.big);                // nonce low 32 bits
  header.setUint16(14, body.length, Endian.big);         // body length

  final token = Uint8List(16 + body.length);
  token.setRange(0, 16, header.buffer.asUint8List());
  token.setRange(16, token.length, body);

  return '04${base64.encode(token)}';
}
