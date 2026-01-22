// Patch all deal_ads in Firestore to add authorID field (set to listerId)
// Usage: node patch_deal_ads_authorid.js

const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert(require('../caribtap-firebase-adminsdk-fbsvc-f2e46066e1.json'))
});

async function patchDealAds() {
  const db = admin.firestore();
  const adsSnap = await db.collection('deal_ads').get();
  let patched = 0;
  for (const doc of adsSnap.docs) {
    const data = doc.data();
    if (!data.authorID && data.listerId) {
      console.log(`Patching ${doc.id} with authorID: ${data.listerId}`);
      await doc.ref.update({ authorID: data.listerId });
      patched++;
    }
  }
  console.log(`Patch complete. ${patched} documents updated.`);
}

patchDealAds().catch(console.error);
