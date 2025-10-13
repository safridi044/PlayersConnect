const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.sendNewMessageNotification = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const db = getFirestore();
    const messageData = event.data.data();
    const chatId = event.params.chatId;
    const senderId = messageData.senderId;
    const senderName = messageData.senderName || "Someone";

    // 🔹 Get participants from parent chat document
    const chatDoc = await db.collection("chats").doc(chatId).get();
    const participants = chatDoc.get("participants");

    if (!participants || participants.length < 2) {
      console.log("⚠️ Invalid participants list");
      return;
    }

    // Determine receiver (the one who’s not the sender)
    const receiverId = participants.find((id) => id !== senderId);
    if (!receiverId) {
      console.log("⚠️ Could not determine receiver");
      return;
    }

    // 🔹 Get receiver's FCM token
    const receiverDoc = await db.collection("players").doc(receiverId).get();
    const fcmToken = receiverDoc.get("fcmToken");

    if (!fcmToken) {
      console.log(`⚠️ No FCM token for receiver ${receiverId}`);
      return;
    }

    // 🔹 Send notification
    const payload = {
      notification: {
        title: `${senderName} sent you a message 💬`,
        body: messageData.text || "Tap to open chat",
      },
      data: {
        chatId: chatId,
      },
      token: fcmToken,
    };

    try {
      await getMessaging().send(payload);
      console.log(`✅ Message notification sent to ${receiverId}`);
    } catch (error) {
      console.error("❌ Error sending notification:", error);
    }
  }
);