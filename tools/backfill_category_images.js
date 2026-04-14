/**
 * Backfill category images for canonical taxonomy categories.
 *
 * Strategy:
 * - Map legacy category image URLs to canonical primary slugs.
 * - If a subcategory has no photo, inherit its parent primary photo.
 *
 * Usage:
 *   node tools/backfill_category_images.js --project-id caribtap --credentials /abs/path/key.json
 *   node tools/backfill_category_images.js --commit --project-id caribtap --credentials /abs/path/key.json
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

function normalizeText(value) {
  return (value || '').toString().trim().toLowerCase();
}

function resolveCredentialPath() {
  const argCredentialPath = getArgValue('credentials');
  if (argCredentialPath) return path.resolve(argCredentialPath);
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
  if (argProjectId) return argProjectId;
  if (process.env.GOOGLE_CLOUD_PROJECT) return process.env.GOOGLE_CLOUD_PROJECT;
  if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;

  const firebaseRcPath = path.resolve(__dirname, '../.firebaserc');
  if (fs.existsSync(firebaseRcPath)) {
    const firebaseRc = JSON.parse(fs.readFileSync(firebaseRcPath, 'utf8'));
    if (firebaseRc.projects?.default) return firebaseRc.projects.default;
    const values = Object.values(firebaseRc.projects || {});
    if (values.length > 0 && typeof values[0] === 'string') return values[0];
  }

  return undefined;
}

const resolvedCredential = resolveCredential();
const resolvedProjectId = resolveProjectId();
const shouldCommit = process.argv.includes('--commit');

admin.initializeApp({
  credential: resolvedCredential.credential,
  projectId: resolvedProjectId,
});

const legacyTitleToPrimarySlugs = {
  'food & beverage': ['food-beverage'],
  'retail & stores': ['retail-shopping'],
  'personal services': ['beauty-personal-care'],
  'health & wellness': ['health-wellness'],
  'transportation & mobile services': ['automotive', 'travel-tourism'],
  'construction & handyman services': ['home-services', 'real-estate-rentals'],
  'digital & creative': ['professional-services', 'events-entertainment', 'technology-electronics'],
  'street & seasonal hustles': ['community-nonprofit', 'other'],
  'education & skills transfer': ['education-training'],
  'landscaping & home garden': ['agriculture-local-produce'],
};

async function main() {
  console.log(`Auth source: ${resolvedCredential.source}`);
  console.log(`Project: ${resolvedProjectId || 'auto-detect'}`);
  console.log(`Mode: ${shouldCommit ? 'commit' : 'dry-run'}`);

  const db = admin.firestore();
  const snap = await db.collection('categories').get();

  const categories = snap.docs.map((doc) => ({ id: doc.id, ref: doc.ref, ...(doc.data() || {}) }));

  const primaryBySlug = new Map();
  const activeCategories = [];
  const legacyWithPhoto = [];

  for (const cat of categories) {
    const isActive = cat.isActive !== false;
    const slug = (cat.slug || '').toString().trim();
    const title = (cat.title || '').toString().trim();
    const parentSlug = (cat.parentSlug || '').toString().trim();
    const photo = (cat.photo || '').toString().trim();

    if (isActive) {
      const shaped = { ...cat, slug, title, parentSlug, photo };
      activeCategories.push(shaped);
      if (!parentSlug && slug) {
        primaryBySlug.set(slug, shaped);
      }
    } else if (photo) {
      legacyWithPhoto.push({ title, photo });
    }
  }

  const primaryPhotoBySlug = new Map();
  for (const legacy of legacyWithPhoto) {
    const key = normalizeText(legacy.title);
    const primarySlugs = legacyTitleToPrimarySlugs[key] || [];
    for (const primarySlug of primarySlugs) {
      if (!primaryPhotoBySlug.has(primarySlug)) {
        primaryPhotoBySlug.set(primarySlug, legacy.photo);
      }
    }
  }

  const updates = [];

  // Fill missing photos on primaries first.
  for (const [slug, primary] of primaryBySlug.entries()) {
    if (primary.photo) continue;
    const mappedPhoto = primaryPhotoBySlug.get(slug);
    if (!mappedPhoto) continue;
    updates.push({
      ref: primary.ref,
      data: {
        photo: mappedPhoto,
        imageBackfilledAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      reason: `primary:${slug}`,
    });
    primary.photo = mappedPhoto;
  }

  // Then cascade parent photo to children with empty photo.
  for (const category of activeCategories) {
    if (category.photo) continue;
    if (!category.parentSlug) continue;
    const parent = primaryBySlug.get(category.parentSlug);
    if (!parent || !parent.photo) continue;

    updates.push({
      ref: category.ref,
      data: {
        photo: parent.photo,
        imageBackfilledFromParentSlug: category.parentSlug,
        imageBackfilledAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      reason: `child:${category.slug || category.id}`,
    });
  }

  console.log(`Active categories: ${activeCategories.length}`);
  console.log(`Legacy categories with photos: ${legacyWithPhoto.length}`);
  console.log(`Category photo updates planned: ${updates.length}`);

  if (!shouldCommit) {
    const sample = updates.slice(0, 12).map((u) => u.reason);
    console.log(`Sample updates: ${sample.join(', ')}`);
    console.log('Dry run complete. Re-run with --commit to apply image updates.');
    return;
  }

  let batch = db.batch();
  let count = 0;
  for (const update of updates) {
    batch.update(update.ref, update.data);
    count += 1;
    if (count >= 500) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) {
    await batch.commit();
  }

  console.log(`Applied category image updates: ${updates.length}`);
}

main().catch((error) => {
  if (String(error?.message || '').includes('Could not load the default credentials')) {
    console.error('Missing Google credentials. Pass --credentials /absolute/path/to/service-account.json');
  }
  console.error('Category image backfill failed:', error);
  process.exit(1);
});
