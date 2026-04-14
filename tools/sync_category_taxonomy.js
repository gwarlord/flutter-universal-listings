/**
 * Sync category taxonomy seed data into Firestore.
 *
 * This script upserts the canonical category taxonomy from
 * tools/category_taxonomy_seed.json into the categories collection,
 * populating slug and parentSlug on actual documents.
 *
 * Usage:
 * 1. Install dependencies: npm install firebase-admin
 * 2. Dry run: node tools/sync_category_taxonomy.js
 * 3. Dry run with explicit credentials/project:
 *    node tools/sync_category_taxonomy.js --credentials /path/key.json --project-id caribtap
 * 4. Commit upserts: node tools/sync_category_taxonomy.js --commit
 * 5. Commit and deactivate legacy active categories:
 *    node tools/sync_category_taxonomy.js --commit --deactivate-legacy
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
const shouldDeactivateLegacy = process.argv.includes('--deactivate-legacy');
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

function dedupeStrings(values) {
  const output = [];
  const seen = new Set();
  for (const value of values || []) {
    const normalized = (value || '').toString().trim();
    if (!normalized) {
      continue;
    }
    const key = normalized.toLowerCase();
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    output.push(normalized);
  }
  return output;
}

function readSeedFile() {
  const seedPath = path.join(__dirname, 'category_taxonomy_seed.json');
  const parsed = JSON.parse(fs.readFileSync(seedPath, 'utf8'));
  if (!parsed || !Array.isArray(parsed.documents)) {
    throw new Error('Seed file is missing a documents array.');
  }
  return parsed;
}

function buildLookupMaps(existingDocs) {
  const byId = new Map();
  const bySlug = new Map();
  const byTitle = new Map();

  for (const doc of existingDocs) {
    byId.set(normalizeText(doc.id), doc);
    if (normalizeText(doc.slug)) {
      bySlug.set(normalizeText(doc.slug), doc);
    }
    if (normalizeText(doc.title)) {
      byTitle.set(normalizeText(doc.title), doc);
    }
  }

  return { byId, bySlug, byTitle };
}

function chooseExistingMatch(seedDoc, lookup) {
  const idMatch = lookup.byId.get(normalizeText(seedDoc.id));
  if (idMatch) {
    return idMatch;
  }

  const slugMatch = lookup.bySlug.get(normalizeText(seedDoc.slug));
  if (slugMatch) {
    return slugMatch;
  }

  const titleMatch = lookup.byTitle.get(normalizeText(seedDoc.title));
  if (titleMatch) {
    return titleMatch;
  }

  return null;
}

function buildCanonicalPayload(seedDoc, existingDoc) {
  const seedSlug = seedDoc.slug || slugify(seedDoc.title) || seedDoc.id;
  const existingPhoto = (existingDoc?.photo || existingDoc?.photoUrl || existingDoc?.image || existingDoc?.icon || '').toString().trim();
  const seedPhoto = (seedDoc.photo || '').toString().trim();
  const payload = {
    slug: seedSlug,
    title: seedDoc.title,
    photo: seedPhoto || existingPhoto || '',
    isActive: seedDoc.isActive !== false,
    sortOrder: Number.isInteger(seedDoc.sortOrder) ? seedDoc.sortOrder : parseInt(seedDoc.sortOrder || '0', 10) || 0,
    synonyms: dedupeStrings([
      ...(Array.isArray(existingDoc?.synonyms) ? existingDoc.synonyms : []),
      ...(Array.isArray(seedDoc.synonyms) ? seedDoc.synonyms : []),
    ]),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const parentSlug = (seedDoc.parentSlug || '').toString().trim();
  if (parentSlug) {
    payload.parentSlug = parentSlug;
  }

  return payload;
}

async function commitOperations(operations) {
  let batch = db.batch();
  let count = 0;

  for (const operation of operations) {
    if (operation.type === 'set') {
      batch.set(operation.ref, operation.data, { merge: true });
    } else {
      batch.update(operation.ref, operation.data);
    }

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

async function syncCategoryTaxonomy() {
  const seed = readSeedFile();
  const collectionName = seed.collection || 'categories';
  console.log(`Auth source: ${resolvedCredential.source}`);
  console.log(`Project: ${resolvedProjectId || 'auto-detect'}`);
  console.log(`Mode: ${shouldCommit ? 'commit' : 'dry-run'}`);
  console.log(`Deactivate legacy categories: ${shouldDeactivateLegacy ? 'yes' : 'no'}`);
  console.log(`Collection: ${collectionName}`);

  const existingSnapshot = await db.collection(collectionName).get();
  const existingDocs = existingSnapshot.docs.map((doc) => {
    const data = doc.data() || {};
    return {
      id: doc.id,
      slug: (data.slug || '').toString().trim(),
      title: (data.title || data.name || '').toString().trim(),
      photo: (data.photo || data.photoUrl || data.image || data.icon || '').toString().trim(),
      isActive: data.isActive !== false,
      sortOrder: Number.isInteger(data.sortOrder) ? data.sortOrder : parseInt(data.sortOrder || '0', 10) || 0,
      parentSlug: (data.parentSlug || '').toString().trim(),
      synonyms: Array.isArray(data.synonyms) ? data.synonyms : [],
      ref: doc.ref,
    };
  });

  const lookup = buildLookupMaps(existingDocs);
  const upsertOperations = [];
  const createdIds = [];
  const updatedIds = [];

  for (const seedDoc of seed.documents) {
    const existingDoc = chooseExistingMatch(seedDoc, lookup);
    const targetRef = db.collection(collectionName).doc(seedDoc.id);
    const payload = buildCanonicalPayload(seedDoc, existingDoc);

    const existingCanonical = existingSnapshot.docs.find((doc) => doc.id === seedDoc.id);
    const targetExists = Boolean(existingCanonical);

    upsertOperations.push({
      type: 'set',
      ref: targetRef,
      data: payload,
      id: seedDoc.id,
    });

    if (targetExists) {
      updatedIds.push(seedDoc.id);
    } else {
      createdIds.push(seedDoc.id);
    }
  }

  const canonicalSeedIds = new Set(seed.documents.map((doc) => doc.id));
  const legacyDeactivateOperations = existingDocs
    .filter((doc) => doc.isActive)
    .filter((doc) => !canonicalSeedIds.has(doc.id))
    .filter((doc) => !seed.documents.some((seedDoc) => normalizeText(seedDoc.slug) === normalizeText(doc.slug)))
    .map((doc) => ({
      type: 'update',
      ref: doc.ref,
      data: {
        isActive: false,
        legacyCategory: true,
        deactivatedByTaxonomySyncAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      id: doc.id,
    }));

  console.log(`Existing docs scanned: ${existingDocs.length}`);
  console.log(`Canonical seed docs: ${seed.documents.length}`);
  console.log(`Docs to create: ${createdIds.length}`);
  console.log(`Docs to update: ${updatedIds.length}`);
  console.log(`Legacy docs to deactivate: ${legacyDeactivateOperations.length}`);

  if (!shouldCommit) {
    console.log('Dry run complete. Re-run with --commit to apply taxonomy changes.');
    return;
  }

  await commitOperations(upsertOperations);
  console.log(`Upserted canonical category docs: ${upsertOperations.length}`);

  if (shouldDeactivateLegacy && legacyDeactivateOperations.length > 0) {
    await commitOperations(legacyDeactivateOperations);
    console.log(`Deactivated legacy category docs: ${legacyDeactivateOperations.length}`);
  }

  console.log('Category taxonomy sync complete.');
}

syncCategoryTaxonomy()
  .then(() => process.exit(0))
  .catch((error) => {
    if (String(error?.message || '').includes('Could not load the default credentials')) {
      console.error('Missing Google credentials. Run with one of these options:');
      console.error('  1) --credentials /absolute/path/to/service-account.json');
      console.error('  2) export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json');
      console.error('Also pass --project-id caribtap if project auto-detection is unavailable.');
    }
    console.error('Category taxonomy sync failed:', error);
    process.exit(1);
  });