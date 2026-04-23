import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/call_model.dart';

class SignalingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _callsCollection = 'calls';

  /// Creates a new call document in Firestore. Returns the callId.
  Future<String> initiateCall({
    required String callId,
    required String roomId,
    required String callerId,
    required String callerName,
  }) async {
    try {
      final call = CallModel(
        callId: callId,
        roomId: roomId,
        callerId: callerId,
        callerName: callerName,
        status: 'ringing',
        timestamp: DateTime.now(),
      );
      await _db.collection(_callsCollection).doc(callId).set(call.toMap());
      debugPrint('[SignalingService] Call initiated: $callId');
      return callId;
    } catch (e, stack) {
      debugPrint('[SignalingService] initiateCall failed: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  /// Listens for status changes on a specific call.
  Stream<String> watchCallStatus(String callId) {
    return _db
        .collection(_callsCollection)
        .doc(callId)
        .snapshots()
        .map((snap) => snap.data()?['status'] as String? ?? 'ended')
        .handleError((e, stack) {
          debugPrint('[SignalingService] watchCallStatus error: $e');
          debugPrint(stack.toString());
        });
  }

  /// Updates call status (e.g., "ended").
  Future<void> updateCallStatus(String callId, String status) async {
    try {
      await _db
          .collection(_callsCollection)
          .doc(callId)
          .update({'status': status});
      debugPrint('[SignalingService] Call $callId status -> $status');
    } catch (e, stack) {
      debugPrint('[SignalingService] updateCallStatus failed: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  /// Deletes call document after call ends.
  Future<void> deleteCall(String callId) async {
    try {
      await _db.collection(_callsCollection).doc(callId).delete();
      debugPrint('[SignalingService] Call deleted: $callId');
    } catch (e, stack) {
      debugPrint('[SignalingService] deleteCall failed: $e');
      debugPrint(stack.toString());
    }
  }
}
