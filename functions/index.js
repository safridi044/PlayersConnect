const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// 🚀 Trigger when a new message is created
exports.sendNewMessageNotification = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const db = getFirestore();
    const messageData = event.data.data();
    const chatId = event.params.chatId;
    const senderId = messageData.senderId;
    const senderName = messageData.senderName || "Someone";

    // 🔹 Fetch chat document to get both participants
    const chatDoc = await db.collection("chats").doc(chatId).get();
    const participants = chatDoc.get("participants");

    if (!participants || participants.length < 2) {
      console.log("⚠️ Invalid or missing participants list");
      return;
    }

    // 🔹 Determine receiver (the one who isn't the sender)
    const receiverId = participants.find((id) => id !== senderId);
    if (!receiverId) {
      console.log("⚠️ Could not determine receiver");
      return;
    }

    // 🔹 Get receiver document
    const receiverDoc = await db.collection("players").doc(receiverId).get();

    // Try to get multiple tokens (array) first, fallback to single token
    let tokens = receiverDoc.get("fcmTokens") || [];
    const singleToken = receiverDoc.get("fcmToken");
    if (tokens.length === 0 && singleToken) tokens = [singleToken];

    if (tokens.length === 0) {
      console.log(`⚠️ No FCM tokens found for receiver ${receiverId}`);
      return;
    }

    // 🔹 Create the notification payload
    const payload = {
      notification: {
        title: `${senderName} sent you a message 💬`,
        body: messageData.text || "Tap to open chat",
      },
      data: {
        chatId: chatId,
        senderId: senderId,
      },
    };

    try {
      // 🔹 Send to all device tokens (multicast)
      const response = await getMessaging().sendEachForMulticast({
        tokens: tokens,
        notification: payload.notification,
        data: payload.data,
      });

      // Remove invalid tokens
      const invalidTokens = [];
      response.responses.forEach((res, index) => {
        if (!res.success) {
          console.warn(
            `⚠️ Failed for token[${index}] of ${receiverId}:`,
            res.error?.message
          );
          invalidTokens.push(tokens[index]);
        }
      });

      if (invalidTokens.length > 0) {
        const validTokens = tokens.filter((t) => !invalidTokens.includes(t));
        await receiverDoc.ref.update({ fcmTokens: validTokens });
        console.log(
          `🧹 Cleaned ${invalidTokens.length} invalid tokens for ${receiverId}`
        );
      }

      console.log(
        `✅ Sent message notification to ${receiverId} (${tokens.length} devices)`
      );
    } catch (error) {
      console.error("❌ Error sending notification:", error);
    }
  }
);