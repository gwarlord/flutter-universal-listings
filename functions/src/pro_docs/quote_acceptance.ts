import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();

interface AcceptQuoteInput {
  token: string;
  accepterName?: string;
  accepterEmail?: string;
}

export const acceptQuoteByToken = functions.https.onCall(
  async (data: AcceptQuoteInput) => {
    const token = (data.token || "").trim();
    if (!token) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing token"
      );
    }

    const publicDoc = await db.collection("public_docs").doc(token).get();
    if (!publicDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Token not found");
    }

    const publicData = publicDoc.data() || {};
    if (publicData.type !== "quote") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Token is not for a quote"
      );
    }

    const expiresAt = publicData.expiresAt?.toDate?.();
    if (expiresAt && expiresAt.getTime() < Date.now()) {
      throw new functions.https.HttpsError(
        "deadline-exceeded",
        "Token has expired"
      );
    }

    const ownerUid = publicData.ownerUid as string | undefined;
    const docId = publicData.docId as string | undefined;
    if (!ownerUid || !docId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Token is missing owner or document reference"
      );
    }

    const quoteRef = db.collection("users").doc(ownerUid).collection("quotes").doc(docId);
    await quoteRef.set(
      {
        status: "accepted",
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      ownerUid,
      quoteId: docId,
    };
  }
);
