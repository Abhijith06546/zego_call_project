const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

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
