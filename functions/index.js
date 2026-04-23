const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const crypto = require('crypto');

initializeApp();

// ─── Zego credentials (keep server-side only) ─────────────────────────────
const ZEGO_APP_ID = 1537619792;
const ZEGO_APP_SIGN = 'cb6372fef38be6b9eb7eed4e894ec0ef0a0d52a710fd1caf19381727fb3fb1ea';

function _generateToken04(appId, userId, secretBytes, effectiveTimeInSeconds, payload) {
  const createTime = Math.floor(Date.now() / 1000);
  const nonce = Math.floor(Math.random() * 2147483647);
  const expireTime = createTime + effectiveTimeInSeconds;

  const info = JSON.stringify({
    app_id: appId,
    user_id: userId,
    nonce,
    ctime: createTime,
    expire: expireTime,
    payload: payload || '',
  });

  const iv = crypto.randomBytes(16);
  // AES-128-CBC; key = MD5 of the raw 32-byte secret
  const key = crypto.createHash('md5').update(secretBytes).digest();
  const cipher = crypto.createCipheriv('aes-128-cbc', key, iv);
  const ciphertext = Buffer.concat([cipher.update(Buffer.from(info, 'utf8')), cipher.final()]);

  const body = Buffer.concat([iv, ciphertext]);

  // Binary: [version:2][expire:4][nonce_hi:4][nonce_lo:4][bodyLen:2][body]
  const buf = Buffer.alloc(16 + body.length);
  buf.writeUInt16BE(4, 0);
  buf.writeUInt32BE(expireTime, 2);
  buf.writeInt32BE(0, 6);            // nonce high 32 bits (always 0 for int32 nonce)
  buf.writeInt32BE(nonce, 10);       // nonce low 32 bits
  buf.writeUInt16BE(body.length, 14);
  body.copy(buf, 16);

  return '04' + buf.toString('base64');
}

exports.getZegoToken = onCall({ cors: true }, (request) => {
  const { userId, roomId } = request.data;
  if (!userId) throw new Error('userId is required');

  const secretBytes = Buffer.from(ZEGO_APP_SIGN, 'hex');
  const token = _generateToken04(
    ZEGO_APP_ID,
    userId,
    secretBytes,
    3600,
    roomId ? JSON.stringify({ room_id: roomId }) : '',
  );

  console.log(`[getZegoToken] token issued for userId=${userId} roomId=${roomId}`);
  return { token };
});

exports.notifyIncomingCall = onDocumentCreated('calls/{callId}', async (event) => {
  const call = event.data.data();

  // Only notify for ringing calls
  if (call.status !== 'ringing') return null;

  const callId = event.params.callId;
  const callerName = call.callerName || 'Web User';
  const roomId = call.roomId || '';

  // Get the executive's FCM token
  const db = getFirestore();
  const execDoc = await db.collection('executives').doc('main').get();
  if (!execDoc.exists) {
    console.log('No executive FCM token found');
    return null;
  }

  const fcmToken = execDoc.data().fcmToken;
  if (!fcmToken) {
    console.log('FCM token is empty');
    return null;
  }

  // Send high-priority FCM notification
  const message = {
    token: fcmToken,
    notification: {
      title: 'Incoming Call',
      body: `${callerName} is calling...`,
    },
    data: {
      callId: callId,
      roomId: roomId,
      callerName: callerName,
      type: 'incoming_call',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'incoming_calls',
        priority: 'max',
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
  };

  try {
    const response = await getMessaging().send(message);
    console.log('FCM sent successfully:', response);
  } catch (error) {
    console.error('FCM send error:', error);
  }

  return null;
});
