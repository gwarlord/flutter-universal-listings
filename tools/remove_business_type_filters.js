/**
 * Remove legacy "Business Type" filter keys from listing documents.
 *
 * Usage:
 *   node tools/remove_business_type_filters.js
 *   node tools/remove_business_type_filters.js --commit
 *   node tools/remove_business_type_filters.js --commit --project-id caribtap
 *   node tools/remove_business_type_filters.js --commit --credentials /abs/path/key.json
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
    if (value === longFlag) return argv[i + 1];
    if (value.startsWith(eqPrefix)) return value.slice(eqPrefix.length);
  }
  return undefined;
}

function normalize(value) {
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
  const argCredentialPath = getArgValue('credentials');
  if (argCredentialPath) {
    const resolvedArgPath = path.resolve(argCredentialPath);
    if (!fs.existsSync(resolvedArgPath)) {
      throw new Error(`Credentials file not found: ${resolvedArgPath}`);
    }
    const serviceAccount = require(resolvedArgPath);
    return {
      credential: admin.credential.cert(serviceAccount),
      source: `service-account:${resolvedArgPath}`,
    };
  }

  const envCredentialPath = process.env.GOOGLE_APPLICATION_CREDENTIALS
    ? path.resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS)
    : null;
  if (envCredentialPath && fs.existsSync(envCredentialPath)) {
    const serviceAccount = require(envCredentialPath);
    return {
      credential: admin.credential.cert(serviceAccount),
      source: `service-account:${envCredentialPath}`,
    };
  }

  if (envCredentialPath && !fs.existsSync(envCredentialPath)) {
    console.warn(
      `Ignoring invalid GOOGLE_APPLICATION_CREDENTIALS path: ${envCredentialPath}`,
    );
    delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
  }

  const defaultCredentialPath = resolveCredentialPath();
  if (fs.existsSync(defaultCredentialPath)) {
    const serviceAccount = require(defaultCredentialPath);
    return {
      credential: admin.credential.cert(serviceAccount),
      source: `service-account:${defaultCredentialPath}`,
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

const shouldCommit = process.argv.includes('--commit');
const batchLimit = 500;
const keyNamesToRemove = new Set(['business type', 'business types']);

const resolvedCredential = resolveCredential();
const resolvedProjectId = resolveProjectId();

admin.initializeApp({
  credential: resolvedCredential.credential,
  projectId: resolvedProjectId,
});

function removeLegacyBusinessTypeKeys(filters) {
  if (!filters || typeof filters !== 'object' || Array.isArray(filters)) {
    return { changed: false, next: filters, removedKeys: [] };
  }

  const next = { ...filters };
  const removedKeys = [];

  for (const key of Object.keys(next)) {
    if (keyNamesToRemove.has(normalize(key))) {
      removedKeys.push(key);
      delete next[key];
    }
  }

  return {
    changed: removedKeys.length > 0,
    next,
    removedKeys,
  };
}

async function commitUpdates(db, updates) {
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

async function main() {
  const db = admin.firestore();
  const listingsSnap = await db.collection('listings').get();

  const updates = [];
  const touchedIds = [];
  let untouched = 0;

  for (const doc of listingsSnap.docs) {
    const data = doc.data() || {};
    const result = removeLegacyBusinessTypeKeys(data.filters);

    if (!result.changed) {
      untouched += 1;
      continue;
    }

    updates.push({
      ref: doc.ref,
      data: {
        filters: result.next,
      },
    });

    touchedIds.push({ id: doc.id, removedKeys: result.removedKeys });
  }

  console.log(`Auth source: ${resolvedCredential.source}`);
  console.log(`Project: ${resolvedProjectId || 'auto-detect'}`);
  console.log(`Mode: ${shouldCommit ? 'commit' : 'dry-run'}`);
  console.log(`Listings scanned: ${listingsSnap.size}`);
  console.log(`Listings to update: ${updates.length}`);
  console.log(`Listings unchanged: ${untouched}`);

  if (touchedIds.length > 0) {
    console.log('Sample updates:', touchedIds.slice(0, 20));
  }

  if (!shouldCommit) {
    console.log('Dry run complete. Re-run with --commit to apply updates.');
    return;
  }

  if (updates.length === 0) {
    console.log('No updates needed.');
    return;
  }

  await commitUpdates(db, updates);
  console.log(`Applied updates: ${updates.length}`);
}

main().catch((error) => {
  if (String(error?.message || '').includes('Could not load the default credentials')) {
    console.error('Missing Google credentials. Pass --credentials /absolute/path/to/service-account.json');
  }
  console.error('Business Type filter cleanup failed:', error);
  process.exit(1);
});
