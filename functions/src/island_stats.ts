import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

type IslandRequestCountry = {
  id?: string;
  isoCode?: string;
  name?: string;
};

type IslandResponseItem = {
  id: string;
  isoCode: string;
  name: string;
  listingsCount: number;
  usersCount: number;
};

type IslandResponseItemInternal = IslandResponseItem & {
  _userIds: Set<string>;
};

function normalizeIsoCode(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(normalized)) return null;
  return normalized;
}

function normalizeCountryId(value: unknown, fallbackIsoCode: string): string {
  if (typeof value !== "string") return fallbackIsoCode.toLowerCase();
  const normalized = value.trim().toLowerCase();
  return normalized.length > 0 ? normalized : fallbackIsoCode.toLowerCase();
}

export const getIslandStats = functions.https.onCall(async (data) => {
  const countriesInput = (data?.countries ?? []) as IslandRequestCountry[];
  if (!Array.isArray(countriesInput) || countriesInput.length === 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "countries is required and must be a non-empty array"
    );
  }

  if (countriesInput.length > 80) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "countries cannot exceed 80 items"
    );
  }

  try {
    const statsWithUserIds = await Promise.all(
      countriesInput.map(async (country): Promise<IslandResponseItemInternal> => {
        const isoCode = normalizeIsoCode(country.isoCode);
        if (!isoCode) {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "Each country must include a valid 2-letter isoCode"
          );
        }

        const [listingsAgg, usersHomeSnap, usersCountrySnap] = await Promise.all([
          db.collection("listings").where("countryCode", "==", isoCode).count().get(),
          db.collection("users").where("homeCountry", "==", isoCode).get(),
          db.collection("users").where("countryCode", "==", isoCode).get(),
        ]);

        const userIds = new Set<string>();
        usersHomeSnap.docs.forEach((doc) => userIds.add(doc.id));
        usersCountrySnap.docs.forEach((doc) => userIds.add(doc.id));
        const usersCount = userIds.size;

        return {
          id: normalizeCountryId(country.id, isoCode),
          isoCode,
          name: typeof country.name === "string" ? country.name : isoCode,
          listingsCount: listingsAgg.data().count,
          usersCount,
          _userIds: userIds,
        };
      })
    );

    const caribbeanUserIds = new Set<string>();
    const stats = statsWithUserIds.map((item) => {
      item._userIds.forEach((id) => caribbeanUserIds.add(id));
      const { _userIds, ...publicItem } = item;
      return publicItem;
    });

    const totalUsersAgg = await db.collection("users").count().get();
    const totalUsers = totalUsersAgg.data().count;
    const visitorsOutsideCaribbeanUsers = Math.max(
      0,
      totalUsers - caribbeanUserIds.size
    );

    return {
      updatedAt: admin.firestore.Timestamp.now().toMillis(),
      stats,
      visitorsOutsideCaribbeanUsers,
    };
  } catch (error) {
    functions.logger.error("Failed to aggregate island stats", error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      "internal",
      "Could not load island statistics"
    );
  }
});