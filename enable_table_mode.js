// Enable Table Mode for a listing
const admin = require('firebase-admin');
const serviceAccount = require('./caribtap-firebase-adminsdk-fbsvc-f2e46066e1.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function enableTableMode() {
  const listingId = 'qjXVVVDR8lKTGarH7BkD'; // Wendy's
  
  console.log(`🔧 Enabling Table Mode for listing: ${listingId}\n`);
  
  try {
    // Get listing
    const listingDoc = await db.collection('listings').doc(listingId).get();
    
    if (!listingDoc.exists) {
      console.log('❌ Listing not found');
      process.exit(1);
    }
    
    console.log(`✅ Found listing: ${listingDoc.data().title}\n`);
    
    // Enable Table Mode
    await db.collection('listings').doc(listingId).update({
      tableModeEnabled: true,
      tableMode: {
        summonCooldownSeconds: 120,
        billRequestCooldownSeconds: 300
      }
    });
    
    console.log('✅ Table Mode enabled successfully!\n');
    console.log('Settings:');
    console.log('  - tableModeEnabled: true');
    console.log('  - summonCooldownSeconds: 120 (2 minutes)');
    console.log('  - billRequestCooldownSeconds: 300 (5 minutes)\n');
    
    // Check if tables exist
    const tablesSnap = await db.collection('listings').doc(listingId).collection('tables').get();
    console.log(`📋 Found ${tablesSnap.size} tables for this listing\n`);
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

enableTableMode();
