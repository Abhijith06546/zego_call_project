class ZegoConstants {
  // ─── Replace with your ZEGOCLOUD credentials ───────────────────────────────
  static const int appId = 1537619792;
  static const String appSign = 'cb6372fef38be6b9eb7eed4e894ec0ef0a0d52a710fd1caf19381727fb3fb1ea';
  // ───────────────────────────────────────────────────────────────────────────

  static const String webUserId = 'web_user_001';
  static const String webUserName = 'Web User';

  static String callerStreamId(String roomId) => '${roomId}_caller';
  static String executiveStreamId(String roomId) => '${roomId}_executive';
}

class FcmConstants {
  // ─── Get this from Firebase Console → Project Settings → Cloud Messaging ──
  // Enable "Cloud Messaging API (Legacy)" and copy the Server Key
  static const String serverKey = 'YOUR_FCM_SERVER_KEY_HERE';
  // ───────────────────────────────────────────────────────────────────────────
}


