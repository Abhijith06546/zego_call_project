import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

class FcmService {
  /// Reads the executive's FCM token from Firestore and sends an incoming call notification.
  static Future<void> sendCallNotification({
    required String callId,
    required String roomId,
    required String callerName,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('executives')
          .doc('main')
          .get();

      if (!doc.exists) {
        debugPrint('[FcmService] Executive FCM token document not found');
        return;
      }
      final fcmToken = doc.data()?['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('[FcmService] FCM token is null or empty');
        return;
      }

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=${FcmConstants.serverKey}',
        },
        body: jsonEncode({
          'to': fcmToken,
          'priority': 'high',
          'data': {
            'type': 'incoming_call',
            'callId': callId,
            'roomId': roomId,
            'callerName': callerName,
          },
          'notification': {
            'title': 'Incoming Call',
            'body': '$callerName is calling...',
            'android_channel_id': 'incoming_calls',
          },
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'incoming_calls',
              'notification_priority': 'PRIORITY_MAX',
              'default_sound': true,
              'default_vibrate_timings': true,
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('[FcmService] Notification sent successfully');
      } else {
        debugPrint('[FcmService] FCM send failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stack) {
      debugPrint('[FcmService] sendCallNotification error: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }
}
