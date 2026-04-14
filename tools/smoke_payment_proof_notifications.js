/**
 * Smoke test utility for proof-of-payment notification flows (orders + rentals).
 *
 * Safe defaults:
 * - Dry run by default (no writes).
 * - Uses explicit --commit to write data.
 * - Supports automatic cleanup with --cleanup.
 *
 * Usage examples:
 * 1) Dry run:
 *    node tools/smoke_payment_proof_notifications.js
 *
 * 2) Execute write test with default dummy IDs (no real users notified):
 *    node tools/smoke_payment_proof_notifications.js --commit --cleanup
 *
 * 3) Use explicit IDs (only if you want real push notifications tested):
 *    node tools/smoke_payment_proof_notifications.js --commit --cleanup \
 *      --listing-id <listingId> --lister-id <listerUid> --customer-id <customerUid>
 *
 * 4) Cleanup from a previous run file:
 *    node tools/smoke_payment_proof_notifications.js --cleanup-file <path/to/file.json>
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

function nowIso() {
  return new Date().toISOString();
}

function buildIds() {
  const runId = Date.now().toString();
  return {
    runId,
    orderApproveId: `smoke_order_approve_${runId}`,
    orderRejectId: `smoke_order_reject_${runId}`,
    rentalApproveId: `smoke_rental_approve_${runId}`,
    rentalRejectId: `smoke_rental_reject_${runId}`,
  };
}

function buildOrderDoc({ listingId, listerId, customerId }) {
  return {
    listingId,
    listerId,
    customerId,
    status: 'confirmed',
    payment: {
      proofOfPaymentUrl: '',
      proofOfPaymentStatus: '',
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    smokeTest: {
      source: 'tools/smoke_payment_proof_notifications.js',
      createdAtIso: nowIso(),
    },
  };
}

function buildRentalDoc({ listingId, listerId, customerId, status }) {
  const startTime = new Date(Date.now() + 24 * 60 * 60 * 1000);
  const endTime = new Date(Date.now() + 48 * 60 * 60 * 1000);
  return {
    listingId,
    rentalUnitId: 'smoke-unit',
    customerId,
    listerId,
    startTime,
    endTime,
    pricingUnit: 'daily',
    unitPrice: 10,
    quantity: 1,
    subtotal: 10,
    depositAmount: 0,
    totalAmount: 10,
    status,
    listingAcceptsProofOfPayment: true,
    payment: {
      proofOfPaymentUrl: '',
      proofOfPaymentStatus: '',
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    smokeTest: {
      source: 'tools/smoke_payment_proof_notifications.js',
      createdAtIso: nowIso(),
    },
  };
}

async function createDocs(ids, opts) {
  const orderApproveRef = db.collection('order_requests').doc(ids.orderApproveId);
  const orderRejectRef = db.collection('order_requests').doc(ids.orderRejectId);
  const rentalApproveRef = db.collection('rental_bookings').doc(ids.rentalApproveId);
  const rentalRejectRef = db.collection('rental_bookings').doc(ids.rentalRejectId);

  const writes = [
    orderApproveRef.set(buildOrderDoc(opts)),
    orderRejectRef.set(buildOrderDoc(opts)),
    rentalApproveRef.set(buildRentalDoc({ ...opts, status: 'confirmed' })),
    rentalRejectRef.set(buildRentalDoc({ ...opts, status: 'confirmed' })),
  ];

  await Promise.all(writes);
}

async function triggerProofUploads(ids) {
  const proofUrl = (docId) => `https://example.com/smoke-proof/${docId}.jpg`;

  await Promise.all([
    db.collection('order_requests').doc(ids.orderApproveId).update({
      'payment.proofOfPaymentUrl': proofUrl(ids.orderApproveId),
      'payment.proofOfPaymentStatus': 'pending',
      'payment.proofSubmittedAt': admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    db.collection('order_requests').doc(ids.orderRejectId).update({
      'payment.proofOfPaymentUrl': proofUrl(ids.orderRejectId),
      'payment.proofOfPaymentStatus': 'pending',
      'payment.proofSubmittedAt': admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    db.collection('rental_bookings').doc(ids.rentalApproveId).update({
      'payment.proofOfPaymentUrl': proofUrl(ids.rentalApproveId),
      'payment.proofOfPaymentStatus': 'pending',
      'payment.proofSubmittedAt': admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    db.collection('rental_bookings').doc(ids.rentalRejectId).update({
      'payment.proofOfPaymentUrl': proofUrl(ids.rentalRejectId),
      'payment.proofOfPaymentStatus': 'pending',
      'payment.proofSubmittedAt': admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  ]);
}

async function triggerProofReviews(ids) {
  await Promise.all([
    db.collection('order_requests').doc(ids.orderApproveId).update({
      'payment.proofOfPaymentStatus': 'approved',
      'payment.proofReviewedAt': admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    db.collection('order_requests').doc(ids.orderRejectId).update({
      'payment.proofOfPaymentStatus': 'rejected',
      'payment.rejectionReason': 'Smoke test rejection',
      'payment.proofReviewedAt': admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    db.collection('rental_bookings').doc(ids.rentalApproveId).update({
      'payment.proofOfPaymentStatus': 'approved',
      'payment.proofReviewedAt': admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    db.collection('rental_bookings').doc(ids.rentalRejectId).update({
      'payment.proofOfPaymentStatus': 'rejected',
      'payment.rejectionReason': 'Smoke test rejection',
      'payment.proofReviewedAt': admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  ]);
}

async function cleanupDocs(ids) {
  await Promise.all([
    db.collection('order_requests').doc(ids.orderApproveId).delete(),
    db.collection('order_requests').doc(ids.orderRejectId).delete(),
    db.collection('rental_bookings').doc(ids.rentalApproveId).delete(),
    db.collection('rental_bookings').doc(ids.rentalRejectId).delete(),
  ]);
}

function persistRunFile(ids, opts) {
  const outputDir = path.resolve(__dirname, '../temp');
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const outputPath = path.join(outputDir, `smoke_payment_proof_${ids.runId}.json`);
  const payload = {
    runId: ids.runId,
    createdAtIso: nowIso(),
    projectId: resolvedProjectId,
    listingId: opts.listingId,
    listerId: opts.listerId,
    customerId: opts.customerId,
    docs: {
      orderApproveId: ids.orderApproveId,
      orderRejectId: ids.orderRejectId,
      rentalApproveId: ids.rentalApproveId,
      rentalRejectId: ids.rentalRejectId,
    },
  };

  fs.writeFileSync(outputPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
  return outputPath;
}

function readCleanupFile(cleanupFilePath) {
  const raw = fs.readFileSync(path.resolve(cleanupFilePath), 'utf8');
  const parsed = JSON.parse(raw);
  return {
    runId: parsed.runId,
    orderApproveId: parsed.docs.orderApproveId,
    orderRejectId: parsed.docs.orderRejectId,
    rentalApproveId: parsed.docs.rentalApproveId,
    rentalRejectId: parsed.docs.rentalRejectId,
  };
}

async function main() {
  const shouldCommit = hasFlag('commit');
  const shouldCleanup = hasFlag('cleanup');
  const cleanupFile = getArgValue('cleanup-file');

  const listingId = getArgValue('listing-id') || 'smoke_listing';
  const listerId = getArgValue('lister-id') || 'smoke_lister';
  const customerId = getArgValue('customer-id') || 'smoke_customer';

  console.log('Proof Notification Smoke Test');
  console.log('Project:', resolvedProjectId || '(unspecified)');
  console.log('Credential source:', resolvedCredential.source);

  if (cleanupFile) {
    const ids = readCleanupFile(cleanupFile);
    if (!shouldCommit) {
      console.log('[Dry Run] Would cleanup IDs from file:', cleanupFile);
      console.log(ids);
      return;
    }

    await cleanupDocs(ids);
    console.log('[Done] Cleanup completed using file:', cleanupFile);
    return;
  }

  const ids = buildIds();
  const opts = { listingId, listerId, customerId };

  console.log('Target IDs:', opts);
  console.log('Generated docs:', ids);

  if (!shouldCommit) {
    console.log('[Dry Run] No writes were performed. Re-run with --commit to execute.');
    return;
  }

  const runFile = persistRunFile(ids, opts);
  console.log('Run file:', runFile);

  await createDocs(ids, opts);
  console.log('[Step 1/3] Created smoke test docs.');

  await triggerProofUploads(ids);
  console.log('[Step 2/3] Wrote proof upload updates (pending).');

  await triggerProofReviews(ids);
  console.log('[Step 3/3] Wrote proof review updates (approved/rejected).');

  if (shouldCleanup) {
    await cleanupDocs(ids);
    console.log('[Cleanup] Deleted smoke docs.');
  } else {
    console.log('[Info] Smoke docs kept for inspection. Cleanup with:');
    console.log(`node tools/smoke_payment_proof_notifications.js --commit --cleanup-file ${runFile}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Smoke test failed:', error);
    process.exit(1);
  });
