const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendFriendRequestNotification = functions.firestore
  .document('{userId}/Friends/FriendRequests/{requestId}')
  .onCreate(async (snapshot, context) => {
    const recipientUID = context.params.userId;
    const senderUID = snapshot.data().senderUID;

    // Fetch the recipient's FCM token from Firestore
    const recipientDoc = await admin.firestore().collection(recipientUID).doc("Settings").get();
    const fcmToken = recipientDoc.data().fcmToken;

    // Fetch the sender's username or any other details if needed
    const senderDoc = await admin.firestore().collection(senderUID).doc("Settings").get();
    const senderName = senderDoc.data().username;

    // Send the notification
    if (fcmToken) {
      await admin.messaging().sendToDevice(fcmToken, {
        notification: {
          title: 'New Friend Request',
          body: `${senderName} has sent you a friend request.`,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      });
    }
  });
