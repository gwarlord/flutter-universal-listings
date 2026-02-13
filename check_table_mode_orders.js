// Run this in Firebase Console > Firestore > Query Editor
// Or use Firebase CLI: firebase firestore:query order_requests

// This will help diagnose the Table Mode issue
// Paste this query into Firebase Console to find orders with tableSessionId

const admin = require('firebase-admin');
const serviceAccount = require('./caribtap-firebase-adminsdk-fbsvc-f2e46066e1.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

async function checkTableModeOrders() {
  console.log('🔍 Checking orders with tableSessionId...\n');
  
  // Get recent orders
  const ordersSnap = await db.collection('order_requests')
    .orderBy('createdAt', 'desc')
    .limit(50)
    .get();
  
  let tableOrders = [];
  let allOrders = [];
  
  for (const doc of ordersSnap.docs) {
    const data = doc.data();
    const orderId = doc.id.substring(0, 8).toUpperCase();
    
    allOrders.push({
      orderId: orderId,
      fullId: doc.id,
      listingId: data.listingId,
      hasTableSessionId: !!data.tableSessionId,
      tableSessionId: data.tableSessionId,
      tableName: data.tableName,
      tableId: data.tableId,
      fulfillmentMethod: data.fulfillment?.method,
      customerName: data.customer?.firstName || 'Unknown',
      status: data.status,
      createdAt: data.createdAt?.toDate()
    });
    
    if (data.tableSessionId) {
      tableOrders.push(allOrders[allOrders.length - 1]);
    }
  }
  
  console.log(`Found ${ordersSnap.docs.length} total orders`);
  console.log(`Found ${tableOrders.length} orders with tableSessionId\n`);
  
  // Check for Order #77145388
  console.log('🔍 Looking for Order #77145388...\n');
  const specificOrder = allOrders.find(o => o.orderId === '77145388');
  if (specificOrder) {
    console.log('✅ Found Order #77145388:');
    console.log(JSON.stringify(specificOrder, null, 2));
    console.log('');
    
    // Check if there's a table session for this order's customer and listing
    console.log('🔍 Checking for table sessions for this order...\n');
    const sessionsSnap = await db.collection('table_sessions')
      .where('listingId', '==', specificOrder.listingId)
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();
    
    console.log(`Found ${sessionsSnap.docs.length} sessions for Wendy's\n`);
    for (const sessionDoc of sessionsSnap.docs) {
      const sessionData = sessionDoc.data();
      console.log(`Session: ${sessionDoc.id.substring(0, 8)}`);
      console.log(`  Customer: ${sessionData.customerName} (${sessionData.customerUid})`);
      console.log(`  Table: ${sessionData.tableName}`);
      console.log(`  Status: ${sessionData.status}`);
      console.log(`  Created: ${sessionData.createdAt?.toDate()}`);
      console.log(`  Activated: ${sessionData.activatedAt?.toDate() || 'Not activated'}`);
      console.log(`  Closed: ${sessionData.closedAt?.toDate() || 'Not closed'}\n`);
    }
  } else {
    console.log('❌ Order #77145388 not found in recent orders\n');
  }
  
  if (tableOrders.length > 0) {
    console.log('Orders with tableSessionId:\n');
    for (const order of tableOrders) {
      console.log(`Order: ${order.orderId}`);
      console.log(`  ListingId: ${order.listingId}`);
      console.log(`  SessionId: ${order.tableSessionId?.substring(0, 8)}`);
      console.log(`  Table: ${order.tableName}`);
      console.log(`  TableId: ${order.tableId}`);
      console.log(`  Fulfillment: ${order.fulfillmentMethod}`);
      console.log(`  Customer: ${order.customerName}`);
      console.log(`  Status: ${order.status}`);
      console.log(`  Created: ${order.createdAt}\n`);
    }
    
    // Check if those sessions exist
    console.log('🔍 Checking if those sessions exist...\n');
    
    for (const order of tableOrders) {
      const sessionSnap = await db.collection('table_sessions').doc(order.tableSessionId).get();
      if (sessionSnap.exists) {
        const sessionData = sessionSnap.data();
        console.log(`✅ Session ${order.tableSessionId.substring(0, 8)} exists - Status: ${sessionData.status}, Table: ${sessionData.tableName}`);
      } else {
        console.log(`❌ Session ${order.tableSessionId.substring(0, 8)} NOT FOUND (deleted or never created)`);
      }
    }
  }
  
  process.exit(0);
}

checkTableModeOrders().catch(console.error);
