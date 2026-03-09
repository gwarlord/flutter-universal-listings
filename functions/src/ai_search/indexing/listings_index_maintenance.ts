import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();

type PlainObject = Record<string, unknown>;

export const maintainSearchIndexListings = functions.firestore
  .document("listings/{listingId}")
  .onWrite(async (change, context) => {
    const listingId = context.params.listingId as string;
    const indexRef = db.collection("search_index_listings").doc(listingId);

    if (!change.after.exists) {
      await indexRef.delete().catch(() => null);
      return;
    }

    const listing = (change.after.data() || {}) as PlainObject;

    if (shouldRemoveFromIndex(listing)) {
      await indexRef.delete().catch(() => null);
      return;
    }

    const indexDoc = buildIndexDocument(listingId, listing);
    await indexRef.set(indexDoc, { merge: true });
  });

function shouldRemoveFromIndex(listing: PlainObject): boolean {
  const suspended = Boolean(listing.suspended);
  const hidden = Boolean(listing.hidden);
  const isApproved = listing.isApproved === undefined ? true : Boolean(listing.isApproved);
  return suspended || hidden || !isApproved;
}

function normalizeString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function lower(value: unknown): string {
  return normalizeString(value).toLowerCase();
}

function toNumber(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = parseFloat(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

function toSeconds(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value > 1e12 ? Math.floor(value / 1000) : Math.floor(value);
  }

  if (value instanceof admin.firestore.Timestamp) {
    return value.seconds;
  }

  if (value && typeof value === "object" && "seconds" in value) {
    const seconds = (value as { seconds?: unknown }).seconds;
    if (typeof seconds === "number" && Number.isFinite(seconds)) {
      return Math.floor(seconds);
    }
  }

  return Math.floor(Date.now() / 1000);
}

function extractServicesText(services: unknown): string[] {
  if (!Array.isArray(services)) return [];
  const text: string[] = [];

  for (const service of services) {
    if (!service || typeof service !== "object") continue;
    const record = service as PlainObject;
    text.push(normalizeString(record.name));
    text.push(normalizeString(record.description));
    text.push(normalizeString(record.duration));
    text.push(normalizeString(record.price));
  }

  return text.filter(Boolean);
}

function extractMenuText(menuSections: unknown): string[] {
  if (!Array.isArray(menuSections)) return [];
  const text: string[] = [];

  for (const section of menuSections) {
    if (!section || typeof section !== "object") continue;
    const sectionRecord = section as PlainObject;
    text.push(normalizeString(sectionRecord.title));

    const items = sectionRecord.items;
    if (!Array.isArray(items)) continue;

    for (const item of items) {
      if (!item || typeof item !== "object") continue;
      const itemRecord = item as PlainObject;
      text.push(normalizeString(itemRecord.name));
      text.push(normalizeString(itemRecord.description));

      const tags = itemRecord.tags;
      if (Array.isArray(tags)) {
        text.push(tags.map((t) => normalizeString(t)).filter(Boolean).join(" "));
      }
    }
  }

  return text.filter(Boolean);
}

function extractFiltersText(filters: unknown): string[] {
  if (!filters || typeof filters !== "object") return [];

  const text: string[] = [];
  const record = filters as PlainObject;

  for (const [key, value] of Object.entries(record)) {
    text.push(key);

    if (typeof value === "string") {
      text.push(value);
    } else if (Array.isArray(value)) {
      text.push(value.map((v) => normalizeString(v)).filter(Boolean).join(" "));
    } else if (typeof value === "number" || typeof value === "boolean") {
      text.push(String(value));
    }
  }

  return text.filter(Boolean);
}

function tokenize(parts: string[]): string[] {
  const tokens = new Set<string>();

  for (const part of parts) {
    const normalized = lower(part);
    if (!normalized) continue;

    tokens.add(normalized);

    const split = normalized
      .split(/[^a-z0-9]+/g)
      .map((p) => p.trim())
      .filter((p) => p.length >= 2);

    for (const token of split) {
      tokens.add(token);
    }
  }

  return Array.from(tokens);
}

function buildIndexDocument(listingId: string, listing: PlainObject): PlainObject {
  const title = normalizeString(listing.title);
  const description = normalizeString(listing.description);
  const place = normalizeString(listing.place) || normalizeString(listing.location);
  const categoryTitle = normalizeString(listing.categoryTitle) || normalizeString(listing.category);

  const createdAtSeconds = toSeconds(listing.createdAt);
  const updatedAtSeconds = toSeconds(listing.updatedAt ?? listing.createdAt);

  const reviewsCount = toNumber(listing.reviewsCount) ?? toNumber(listing.reviewCount) ?? 0;
  const reviewsSum = toNumber(listing.reviewsSum) ?? 0;
  const averageRating = reviewsCount > 0 ? reviewsSum / reviewsCount : (toNumber(listing.rating) ?? 0);

  const searchKeywords = Array.isArray(listing.searchKeywords)
    ? listing.searchKeywords.map((k) => normalizeString(k)).filter(Boolean)
    : [];

  const servicesText = extractServicesText(listing.services);
  const menuText = extractMenuText(listing.menuSections);
  const filtersText = extractFiltersText(listing.filters);

  const searchableParts = [
    title,
    description,
    place,
    categoryTitle,
    normalizeString(listing.price),
    normalizeString(listing.openingHours),
    normalizeString(listing.locationInstructions),
    normalizeString(listing.phone),
    normalizeString(listing.email),
    normalizeString(listing.website),
    normalizeString(listing.authorName),
    normalizeString(listing.instagram),
    normalizeString(listing.facebook),
    normalizeString(listing.tiktok),
    normalizeString(listing.whatsapp),
    normalizeString(listing.youtube),
    normalizeString(listing.x),
    ...searchKeywords,
    ...servicesText,
    ...menuText,
    ...filtersText,
  ].filter(Boolean);

  return {
    id: listingId,
    sourceCollection: "listings",

    title,
    description,
    category: lower(categoryTitle),
    categoryTitle,
    location: place,
    place,

    price: toNumber(listing.price),
    rating: averageRating,
    averageRating,
    reviewCount: reviewsCount,
    reviewsCount,
    reviewsSum,

    imageUrl: normalizeString(listing.photo) || normalizeString(listing.imageUrl),
    photo: normalizeString(listing.photo) || normalizeString(listing.imageUrl),

    latitude: toNumber(listing.latitude),
    longitude: toNumber(listing.longitude),

    authorName: normalizeString(listing.authorName),
    openingHours: normalizeString(listing.openingHours),
    locationInstructions: normalizeString(listing.locationInstructions),
    website: normalizeString(listing.website),
    phone: normalizeString(listing.phone),
    email: normalizeString(listing.email),
    instagram: normalizeString(listing.instagram),
    facebook: normalizeString(listing.facebook),
    tiktok: normalizeString(listing.tiktok),
    whatsapp: normalizeString(listing.whatsapp),
    youtube: normalizeString(listing.youtube),
    x: normalizeString(listing.x),

    searchKeywords,
    services: Array.isArray(listing.services) ? listing.services : [],
    menuSections: Array.isArray(listing.menuSections) ? listing.menuSections : [],
    filters: (listing.filters as PlainObject | undefined) || {},
    searchableText: tokenize(searchableParts),
    searchableBlob: searchableParts.join(" ").toLowerCase(),

    suspended: Boolean(listing.suspended),
    hidden: Boolean(listing.hidden),
    isApproved: listing.isApproved === undefined ? true : Boolean(listing.isApproved),
    isActive: !Boolean(listing.suspended) && !Boolean(listing.hidden),
    verified: Boolean(listing.verified),
    freshnessStatus: (listing.freshness as PlainObject | undefined)?.status || "",

    createdAt: createdAtSeconds,
    updatedAt: updatedAtSeconds,
    indexedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}
