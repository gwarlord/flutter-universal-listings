/**
 * Migration Script: Add Tap Fields to Existing Listings
 * 
 * This script adds tapCount and tapBadge fields to all existing listings in Firestore.
 * 
 * Usage:
 * 1. Install dependencies: npm install firebase-admin
 * 2. Ensure service account key is in the root directory
 * 3. Run: node migrate_tap_fields.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('../caribtap-firebase-adminsdk-fbsvc-f2e46066e1.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateTapFields() {
  console.log('🚀 Starting migration: Adding tap fields to listings...\n');
  
  try {
    const listingsSnapshot = await db.collection('listings').get();
    const totalListings = listingsSnapshot.size;
    
    if (totalListings === 0) {
      console.log('❌ No listings found in the database.');
      return;
    }
    
    console.log(`📊 Found ${totalListings} listings to migrate.\n`);
    
    // Process in batches of 500 (Firestore batch limit)
    const batchSize = 500;
    let batchCount = 0;
    let migratedCount = 0;
    let skippedCount = 0;
    let batch = db.batch();
    
    for (const doc of listingsSnapshot.docs) {
      const data = doc.data();
      
      // Check if fields already exist
      if (data.hasOwnProperty('tapCount') && data.hasOwnProperty('tapBadge')) {
        console.log(`⏭️  Skipping ${doc.id} - tap fields already exist`);
        skippedCount++;
        continue;
      }
      
      // Add tap fields
      batch.update(doc.ref, {
        tapCount: 0,
        tapBadge: 'none'
      });
      
      batchCount++;
      migratedCount++;
      
      // Commit batch when it reaches the limit
      if (batchCount >= batchSize) {
        await batch.commit();
        console.log(`✅ Committed batch of ${batchCount} updates`);
        batch = db.batch();
        batchCount = 0;
      }
    }
    
    // Commit any remaining updates
    if (batchCount > 0) {
      await batch.commit();
      console.log(`✅ Committed final batch of ${batchCount} updates`);
    }
    
    console.log('\n🎉 Migration complete!');
    console.log(`   Total listings: ${totalListings}`);
    console.log(`   Migrated: ${migratedCount}`);
    console.log(`   Skipped: ${skippedCount}`);
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  }
}

// Run migration
migrateTapFields()
  .then(() => {
    console.log('\n✨ All done! You can now deploy the Tap feature.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Migration failed with error:', error);
    process.exit(1);
  });
