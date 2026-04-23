import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call_model.dart';

class SignalingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _callsCollection = 'calls';

  /// Listens for incoming calls with status "ringing".
  Stream<CallModel?> watchIncomingCall() {
    return _db
        .collection(_callsCollection)
        .where('status', isEqualTo: 'ringing')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return CallModel.fromMap(doc.id, doc.data());
    });
  }

  /// Watches status changes on a specific call document.
  Stream<String> watchCallStatus(String callId) {
    return _db
        .collection(_callsCollection)
        .doc(callId)
        .snapshots()
        .map((snap) => snap.data()?['status'] as String? ?? 'ended');
  }

  /// Updates call status (accepted / rejected / ended).
  Future<void> updateCallStatus(String callId, String status) async {
    await _db
        .collection(_callsCollection)
        .doc(callId)
        .update({'status': status});
  }

  /// Saves this device's FCM token so the web app can target it.
  Future<void> saveExecutiveFcmToken(String token) async {
    await _db.collection('executives').doc('main').set(
      {'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> deleteCall(String callId) async {
    await _db.collection(_callsCollection).doc(callId).delete();
  }
}
