/**
 * Backfill listing category taxonomy fields and optionally deactivate duplicate
 * category documents.
 *
 * Usage:
 * 1. Install dependencies: npm install firebase-admin
 * 2. Dry run: node tools/migrate_listing_categories.js
 * 3. Dry run with explicit credentials/project:
 *    node tools/migrate_listing_categories.js --credentials /path/key.json --project-id caribtap
 * 4. Apply listing updates: node tools/migrate_listing_categories.js --commit
 * 5. Also deactivate duplicate category docs: node tools/migrate_listing_categories.js --commit --deactivate-duplicates
 */

const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');

const runtimeRequire = process.env.ADMIN_RUNTIME_NODE_MODULES
  ? createRequire(path.join(process.env.ADMIN_RUNTIME_NODE_MODULES, 'index.js'))
  : require;

const admin = runtimeRequire('firebase-admin');

function getArgValue(flagName) {
  const longFlag = `--${flagName}`;
  const eqPrefix = `${longFlag}=`;
  const argv = process.argv.slice(2);

  for (let i = 0; i < argv.length; i += 1) {
    const value = argv[i];
    if (value === longFlag) {
      return argv[i + 1];
    }
    if (value.startsWith(eqPrefix)) {
      return value.slice(eqPrefix.length);
    }
  }
  return undefined;
}

function resolveCredentialPath() {
  const argCredentialPath = getArgValue('credentials');
  if (argCredentialPath) {
    return path.resolve(argCredentialPath);
  }

  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return path.resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS);
  }

  return path.resolve(__dirname, '../caribtap-firebase-adminsdk-fbsvc-f2e46066e1.json');
}

function resolveCredential() {
  const credentialPath = resolveCredentialPath();
  if (fs.existsSync(credentialPath)) {
    const serviceAccount = require(credentialPath);
    return {
      credential: admin.credential.cert(serviceAccount),
      source: `service-account:${credentialPath}`,
    };
  }

  return {
    credential: admin.credential.applicationDefault(),
    source: 'application-default-credentials',
  };
}

function resolveProjectId() {
  const argProjectId = getArgValue('project-id');
  if (argProjectId) {
    return argProjectId;
  }

  if (process.env.GOOGLE_CLOUD_PROJECT) {
    return process.env.GOOGLE_CLOUD_PROJECT;
  }

  if (process.env.GCLOUD_PROJECT) {
    return process.env.GCLOUD_PROJECT;
  }

  const firebaseRcPath = path.resolve(__dirname, '../.firebaserc');
  if (fs.existsSync(firebaseRcPath)) {
    const firebaseRc = JSON.parse(fs.readFileSync(firebaseRcPath, 'utf8'));
    if (firebaseRc.projects?.default) {
      return firebaseRc.projects.default;
    }

    const projectValues = Object.values(firebaseRc.projects || {});
    if (projectValues.length > 0 && typeof projectValues[0] === 'string') {
      return projectValues[0];
    }
  }

  return undefined;
}

const resolvedCredential = resolveCredential();
const resolvedProjectId = resolveProjectId();

admin.initializeApp({
  credential: resolvedCredential.credential,
  projectId: resolvedProjectId,
});

const db = admin.firestore();
const shouldCommit = process.argv.includes('--commit');
const shouldDeactivateDuplicates = process.argv.includes('--deactivate-duplicates');
const batchLimit = 500;

function normalizeText(value) {
  return (value || '').toString().trim().toLowerCase();
}

function slugify(value) {
  return normalizeText(value)
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

function categoryKey(category) {
  const parentSlug = normalizeText(category.parentSlug);
  const title = normalizeText(category.title);
  if (title) {
    return `title:${parentSlug}:${title}`;
  }

  const slug = normalizeText(category.slug);
  if (slug) {
    return `slug:${slug}`;
  }
  return `id:${normalizeText(category.id)}`;
}

function categoryScore(category) {
  let score = 0;
  if (normalizeText(category.parentSlug)) score += 8;
  if (normalizeText(category.photo)) score += 4;
  if (Array.isArray(category.synonyms) && category.synonyms.length > 0) score += 2;
  if ((category.sortOrder || 0) > 0) score += 1;
  return score;
}

function choosePreferredCategory(left, right) {
  const leftScore = categoryScore(left);
  const rightScore = categoryScore(right);
  if (leftScore !== rightScore) {
    return rightScore > leftScore ? right : left;
  }
  if ((left.sortOrder || 0) !== (right.sortOrder || 0)) {
    return (right.sortOrder || 0) < (left.sortOrder || 0) ? right : left;
  }
  return (right.title || '').length > (left.title || '').length ? right : left;
}

function buildLegacyMap() {
  return new Map([
    ['food & drink', 'food-beverage'],
    ['food and drink', 'food-beverage'],
    ['restaurants', 'food-beverage'],
    ['restaurant', 'food-beverage'],
    ['shopping', 'retail-shopping'],
    ['retail', 'retail-shopping'],
    ['beauty & spa', 'beauty-personal-care'],
    ['health & fitness', 'health-wellness'],
    ['automotive', 'automotive'],
    ['home services', 'home-services'],
    ['professional services', 'professional-services'],
    ['events', 'events-entertainment'],
    ['entertainment', 'events-entertainment'],
    ['travel & tourism', 'travel-tourism'],
    ['education', 'education-training'],
    ['education & skills transfer', 'education-training'],
    ['real estate', 'real-estate-rentals'],
    ['electronics', 'technology-electronics'],
    ['accommodation', 'travel-tourism'],
    ['construction & handyman services', 'home-services'],
    ['personal services', 'beauty-personal-care'],
    ['digital & creative', 'professional-services'],
    ['skilled trades', 'home-services'],
  ]);
}

function resolveListingCategory(listing, helpers) {
  const { categoriesById, categoriesBySlug, categoriesByTitle, legacyAliasMap } = helpers;
  const categoryId = normalizeText(listing.categoryID);
  if (categoryId && categoriesById.has(categoryId)) {
    return categoriesById.get(categoryId);
  }

  const subcategorySlug = normalizeText(listing.subcategorySlug);
  if (subcategorySlug && categoriesBySlug.has(subcategorySlug)) {
    return categoriesBySlug.get(subcategorySlug);
  }

  const primaryCategorySlug = normalizeText(listing.primaryCategorySlug);
  if (primaryCategorySlug && categoriesBySlug.has(primaryCategorySlug)) {
    return categoriesBySlug.get(primaryCategorySlug);
  }

  const categoryTitle = normalizeText(listing.categoryTitle);
  if (categoryTitle) {
    if (categoriesByTitle.has(categoryTitle)) {
      return categoriesByTitle.get(categoryTitle);
    }

    const titleSlug = slugify(categoryTitle);
    if (titleSlug && categoriesBySlug.has(titleSlug)) {
      return categoriesBySlug.get(titleSlug);
    }

    const legacyPrimarySlug = legacyAliasMap.get(categoryTitle);
    if (legacyPrimarySlug && categoriesBySlug.has(legacyPrimarySlug)) {
      return categoriesBySlug.get(legacyPrimarySlug);
    }
  }

  return null;
}

async function commitUpdates(updates) {
  let batch = db.batch();
  let count = 0;

  for (const update of updates) {
    batch.update(update.ref, update.data);
    count += 1;

    if (count >= batchLimit) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }

  if (count > 0) {
    await batch.commit();
  }
}

async function migrateListingCategories() {
  console.log(`Auth source: ${resolvedCredential.source}`);
  console.log(`Project: ${resolvedProjectId || 'auto-detect'}`);
  console.log(`Mode: ${shouldCommit ? 'commit' : 'dry-run'}`);
  console.log(`Deactivate duplicate category docs: ${shouldDeactivateDuplicates ? 'yes' : 'no'}`);

  const [categoriesSnapshot, listingsSnapshot] = await Promise.all([
    db.collection('categories').get(),
    db.collection('listings').get(),
  ]);

  const parsedCategories = categoriesSnapshot.docs
    .map((doc) => {
      const data = doc.data() || {};
      return {
        id: doc.id,
        slug: (data.slug || slugify(data.title || data.name || '') || doc.id).toString().trim(),
        title: (data.title || data.name || '').toString().trim(),
        photo: (data.photo || data.photoUrl || data.image || data.icon || '').toString().trim(),
        isActive: data.isActive !== false,
        sortOrder: Number.isInteger(data.sortOrder) ? data.sortOrder : parseInt(data.sortOrder || '0', 10) || 0,
        parentSlug: (data.parentSlug || '').toString().trim(),
        synonyms: Array.isArray(data.synonyms) ? data.synonyms.map((item) => item.toString().trim()).filter(Boolean) : [],
        ref: doc.ref,
      };
    })
    .filter((category) => category.isActive);

  const canonicalCategories = new Map();
  const duplicateCategories = [];

  for (const category of parsedCategories) {
    const key = categoryKey(category);
    const existing = canonicalCategories.get(key);
    if (!existing) {
      canonicalCategories.set(key, category);
      continue;
    }

    const preferred = choosePreferredCategory(existing, category);
    const duplicate = preferred.id === existing.id ? category : existing;
    canonicalCategories.set(key, preferred);
    duplicateCategories.push({ duplicate, canonical: preferred, key });
  }

  const categoriesById = new Map();
  const categoriesBySlug = new Map();
  const categoriesByTitle = new Map();
  for (const category of canonicalCategories.values()) {
    categoriesById.set(normalizeText(category.id), category);
    categoriesBySlug.set(normalizeText(category.slug), category);
    categoriesByTitle.set(normalizeText(category.title), category);
  }

  const helpers = {
    categoriesById,
    categoriesBySlug,
    categoriesByTitle,
    legacyAliasMap: buildLegacyMap(),
  };

  const listingUpdates = [];
  let matchedListings = 0;
  let unchangedListings = 0;
  let unresolvedListings = 0;

  for (const doc of listingsSnapshot.docs) {
    const data = doc.data() || {};
    const resolvedCategory = resolveListingCategory(data, helpers);
    if (!resolvedCategory) {
      unresolvedListings += 1;
      continue;
    }

    const primaryCategorySlug = resolvedCategory.parentSlug || resolvedCategory.slug;
    const subcategorySlug = resolvedCategory.parentSlug ? resolvedCategory.slug : '';
    const nextPayload = {
      categoryID: resolvedCategory.id,
      categoryTitle: resolvedCategory.title,
      categoryPhoto: resolvedCategory.photo,
      primaryCategorySlug,
      subcategorySlug,
      categoryTags: Array.isArray(data.categoryTags) ? data.categoryTags : [],
    };

    const hasChanges =
      data.categoryID !== nextPayload.categoryID ||
      (data.categoryTitle || '') !== nextPayload.categoryTitle ||
      (data.categoryPhoto || '') !== nextPayload.categoryPhoto ||
      (data.primaryCategorySlug || '') !== nextPayload.primaryCategorySlug ||
      (data.subcategorySlug || '') !== nextPayload.subcategorySlug ||
      !Array.isArray(data.categoryTags);

    if (!hasChanges) {
      unchangedListings += 1;
      continue;
    }

    matchedListings += 1;
    listingUpdates.push({ ref: doc.ref, data: nextPayload, id: doc.id });
  }

  const duplicateCategoryUpdates = duplicateCategories.map(({ duplicate, canonical }) => ({
    ref: duplicate.ref,
    data: {
      isActive: false,
      mergedIntoCategoryId: canonical.id,
      mergedIntoCategorySlug: canonical.slug,
      mergedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    id: duplicate.id,
  }));

  console.log(`Canonical active categories: ${canonicalCategories.size}`);
  console.log(`Duplicate active categories detected: ${duplicateCategories.length}`);
  console.log(`Listings scanned: ${listingsSnapshot.size}`);
  console.log(`Listings to update: ${listingUpdates.length}`);
  console.log(`Listings already aligned: ${unchangedListings}`);
  console.log(`Listings unresolved: ${unresolvedListings}`);

  if (!shouldCommit) {
    console.log('Dry run complete. Re-run with --commit to apply changes.');
    return;
  }

  if (listingUpdates.length > 0) {
    await commitUpdates(listingUpdates);
    console.log(`Updated listings: ${listingUpdates.length}`);
  }

  if (shouldDeactivateDuplicates && duplicateCategoryUpdates.length > 0) {
    await commitUpdates(duplicateCategoryUpdates);
    console.log(`Deactivated duplicate category docs: ${duplicateCategoryUpdates.length}`);
  }

  console.log('Migration complete.');
}

migrateListingCategories()
  .then(() => process.exit(0))
  .catch((error) => {
    if (String(error?.message || '').includes('Could not load the default credentials')) {
      console.error('Missing Google credentials. Run with one of these options:');
      console.error('  1) --credentials /absolute/path/to/service-account.json');
      console.error('  2) export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json');
      console.error('Also pass --project-id caribtap if project auto-detection is unavailable.');
    }
    console.error('Migration failed:', error);
    process.exit(1);
  });