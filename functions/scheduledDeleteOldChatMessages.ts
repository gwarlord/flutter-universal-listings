import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

// Scheduled function to delete all chat messages older than 14 days
export const scheduledDeleteOldChatMessages = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const db = admin.firestore();
    const fourteenDaysAgo = Date.now() - 14 * 24 * 60 * 60 * 1000;
    const batchSize = 500; // Firestore batch limit
    let deletedCount = 0;

    // Adjust this path if your messages are under /channels/{channelId}/messages
    const chatsSnapshot = await db.collection('chats').get();
    for (const chatDoc of chatsSnapshot.docs) {
      const messagesRef = chatDoc.ref.collection('messages');
      let query = messagesRef.where('createdAt', '<', fourteenDaysAgo).limit(batchSize);
      let oldMessages = await query.get();
      while (!oldMessages.empty) {
        const batch = db.batch();
        oldMessages.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        deletedCount += oldMessages.size;
        oldMessages = await query.get();
      }
    }
    console.log(`Deleted ${deletedCount} old chat messages.`);
    return null;
  });
