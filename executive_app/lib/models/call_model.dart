import 'package:cloud_firestore/cloud_firestore.dart';

class CallModel {
  final String callId;
  final String roomId;
  final String callerId;
  final String callerName;
  final String status; // ringing | accepted | rejected | ended
  final DateTime timestamp;

  CallModel({
    required this.callId,
    required this.roomId,
    required this.callerId,
    required this.callerName,
    required this.status,
    required this.timestamp,
  });

  factory CallModel.fromMap(String id, Map<String, dynamic> map) {
    return CallModel(
      callId: id,
      roomId: map['roomId'] ?? '',
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? 'Web User',
      status: map['status'] ?? 'ringing',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'roomId': roomId,
        'callerId': callerId,
        'callerName': callerName,
        'status': status,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}
