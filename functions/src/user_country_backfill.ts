import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

type BackfillResult = {
  scanned: number;
  updated: number;
  skipped: number;
};

function normalizeIsoCode(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(normalized)) return null;
  return normalized;
}

export const backfillUserCountryFields = functions.https.onCall(
  async (_data, context): Promise<BackfillResult> => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication is required"
      );
    }

    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const isAdmin = callerDoc.exists && callerDoc.data()?.isAdmin === true;
    if (!isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin access is required"
      );
    }

    const usersSnap = await db.collection("users").get();
    let scanned = 0;
    let updated = 0;
    let skipped = 0;

    const batch = db.batch();

    usersSnap.docs.forEach((doc) => {
      scanned += 1;
      const data = doc.data() || {};

      const currentHome = normalizeIsoCode(data.homeCountry);
      const currentCountry = normalizeIsoCode(data.countryCode);

      const nextHome = currentHome ?? currentCountry;
      const nextCountry = currentCountry ?? currentHome;

      const patch: Record<string, unknown> = {};
      if (nextHome && nextHome !== data.homeCountry) {
        patch.homeCountry = nextHome;
      }
      if (nextCountry && nextCountry !== data.countryCode) {
        patch.countryCode = nextCountry;
      }

      if (Object.keys(patch).length === 0) {
        skipped += 1;
        return;
      }

      updated += 1;
      batch.set(doc.ref, patch, { merge: true });
    });

    if (updated > 0) {
      await batch.commit();
    }

    functions.logger.info("User country backfill completed", {
      scanned,
      updated,
      skipped,
      requestedBy: context.auth.uid,
    });

    return {
      scanned,
      updated,
      skipped,
    };
  }
);
