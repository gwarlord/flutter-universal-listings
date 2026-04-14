/**
 * Backfill fulfillment.address from shipping.address for shipping orders.
 *
 * Safe defaults:
 * - Dry-run by default (no writes)
 * - Apply changes only with --commit
 *
 * Usage:
 *   node tools/backfill_fulfillment_address_from_shipping.js
 *   node tools/backfill_fulfillment_address_from_shipping.js --commit
 *   node tools/backfill_fulfillment_address_from_shipping.js --commit --limit 500
 */

const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');

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

function hasFlag(flagName) {
  return process.argv.includes(`--${flagName}`);
}

function resolveRuntimeRequire() {
  if (process.env.ADMIN_RUNTIME_NODE_MODULES) {
    return createRequire(path.join(process.env.ADMIN_RUNTIME_NODE_MODULES, 'index.js'));
  }

  const functionsNodeModules = path.resolve(__dirname, '../functions/node_modules');
  if (fs.existsSync(functionsNodeModules)) {
    return createRequire(path.join(functionsNodeModules, 'firebase-admin/package.json'));
  }

  return require;
}

const runtimeRequire = resolveRuntimeRequire();
const admin = runtimeRequire('firebase-admin');

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

if (!admin.apps.length) {
  admin.initializeApp({
    credential: resolvedCredential.credential,
    projectId: resolvedProjectId,
  });
}

const db = admin.firestore();

function isEmpty(value) {
  return !value || value.toString().trim().length === 0;
}

async function runBackfill({ shouldCommit, limit }) {
  const snapshot = await db
    .collection('order_requests')
    .where('fulfillment.method', '==', 'shipping')
    .limit(limit)
    .get();

  let scanned = 0;
  let eligible = 0;
  let updated = 0;
  let skipped = 0;

  let batch = db.batch();
  let batchOps = 0;

  const maybeCommitBatch = async (force = false) => {
    if (!shouldCommit) return;
    if (batchOps >= 450 || (force && batchOps > 0)) {
      await batch.commit();
      batch = db.batch();
      batchOps = 0;
    }
  };

  for (const doc of snapshot.docs) {
    scanned += 1;
    const data = doc.data() || {};

    const fulfillment = data.fulfillment || {};
    const shipping = data.shipping || {};

    const fulfillmentAddress = fulfillment.address;
    const shippingAddress = shipping.address;

    if (!isEmpty(fulfillmentAddress)) {
      skipped += 1;
      continue;
    }

    if (isEmpty(shippingAddress)) {
      skipped += 1;
      continue;
    }

    eligible += 1;

    if (shouldCommit) {
      batch.update(doc.ref, {
        'fulfillment.address': shippingAddress.toString().trim(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      batchOps += 1;
      updated += 1;
      await maybeCommitBatch();
    }
  }

  await maybeCommitBatch(true);

  return {
    scanned,
    eligible,
    updated,
    skipped,
    dryRun: !shouldCommit,
    limit,
  };
}

async function main() {
  const shouldCommit = hasFlag('commit');
  const limitRaw = getArgValue('limit');
  const limit = Math.max(1, parseInt(limitRaw || '5000', 10));

  console.log('Backfill: fulfillment.address from shipping.address');
  console.log('Project:', resolvedProjectId || '(unspecified)');
  console.log('Credential source:', resolvedCredential.source);
  console.log('Mode:', shouldCommit ? 'COMMIT' : 'DRY_RUN');
  console.log('Limit:', limit);

  const result = await runBackfill({ shouldCommit, limit });

  console.log('Result:');
  console.log(JSON.stringify(result, null, 2));

  if (!shouldCommit) {
    console.log('Dry run complete. Re-run with --commit to apply updates.');
  }
}

main().catch((error) => {
  console.error('Backfill failed:', error);
  process.exit(1);
});
