/**
 * Apply category image URLs from a JSON mapping file.
 *
 * Usage:
 *   node tools/apply_category_image_urls.js --project-id caribtap --credentials /abs/path/key.json
 *   node tools/apply_category_image_urls.js --commit --project-id caribtap --credentials /abs/path/key.json
 *   node tools/apply_category_image_urls.js --commit --mapping tools/category_image_url_map.json --project-id caribtap --credentials /abs/path/key.json
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

function resolveMappingPath() {
  const argMapping = getArgValue('mapping');
  if (argMapping) return path.resolve(argMapping);
  return path.resolve(__dirname, 'category_image_url_map.json');
}

function readMapping(mappingPath) {
  if (!fs.existsSync(mappingPath)) {
    throw new Error(`Mapping file not found: ${mappingPath}`);
  }
  const parsed = JSON.parse(fs.readFileSync(mappingPath, 'utf8'));
  if (!Array.isArray(parsed)) {
    throw new Error('Mapping file must be a JSON array.');
  }
  return parsed;
}

function isLikelyUrl(value) {
  const v = (value || '').toString().trim();
  return v.startsWith('http://') || v.startsWith('https://');
}

const shouldCommit = process.argv.includes('--commit');
const resolvedCredential = resolveCredential();
const resolvedProjectId = resolveProjectId();
const mappingPath = resolveMappingPath();

admin.initializeApp({
  credential: resolvedCredential.credential,
  projectId: resolvedProjectId,
});

async function main() {
  console.log(`Auth source: ${resolvedCredential.source}`);
  console.log(`Project: ${resolvedProjectId || 'auto-detect'}`);
  console.log(`Mode: ${shouldCommit ? 'commit' : 'dry-run'}`);
  console.log(`Mapping file: ${mappingPath}`);

  const mapping = readMapping(mappingPath);
  const db = admin.firestore();
  const categorySnap = await db.collection('categories').get();

  const byId = new Map();
  const bySlug = new Map();

  for (const doc of categorySnap.docs) {
    const data = doc.data() || {};
    byId.set(normalize(doc.id), doc);
    const slug = normalize(data.slug);
    if (slug) bySlug.set(slug, doc);
  }

  const updates = [];
  const skipped = [];
  const notFound = [];

  for (const row of mapping) {
    const id = normalize(row.id);
    const slug = normalize(row.slug);
    const photo = (row.photo || row.url || '').toString().trim();

    if (!isLikelyUrl(photo)) {
      skipped.push({ id: row.id || '', slug: row.slug || '', reason: 'missing-or-invalid-url' });
      continue;
    }

    let target = null;
    if (id && byId.has(id)) target = byId.get(id);
    if (!target && slug && bySlug.has(slug)) target = bySlug.get(slug);

    if (!target) {
      notFound.push({ id: row.id || '', slug: row.slug || '' });
      continue;
    }

    updates.push({
      ref: target.ref,
      data: {
        photo,
        imageUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        imageSource: row.source || 'manual-ai-generated',
      },
      id: target.id,
    });
  }

  console.log(`Categories in Firestore: ${categorySnap.size}`);
  console.log(`Rows in mapping file: ${mapping.length}`);
  console.log(`Valid updates: ${updates.length}`);
  console.log(`Skipped rows: ${skipped.length}`);
  console.log(`Not found: ${notFound.length}`);

  if (skipped.length > 0) {
    console.log('Sample skipped rows:', skipped.slice(0, 10));
  }

  if (notFound.length > 0) {
    console.log('Sample not-found rows:', notFound.slice(0, 10));
  }

  if (!shouldCommit) {
    console.log('Dry run complete. Re-run with --commit to apply image URLs.');
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

  console.log(`Applied image updates: ${updates.length}`);
}

main().catch((error) => {
  if (String(error?.message || '').includes('Could not load the default credentials')) {
    console.error('Missing Google credentials. Pass --credentials /absolute/path/to/service-account.json');
  }
  console.error('Apply category images failed:', error);
  process.exit(1);
});
