# Manual Badge Test

Since the Cloud Function deployment is having issues, let's test if the client side works by manually creating a Firestore document.

## Steps:

1. Open Firebase Console: https://console.firebase.google.com/project/caribtap/firestore
   
2. Navigate to: `users/{your_user_id}/attention/state`

3. Create a document with ID `state` containing:
   ```json
   {
     "counts": {
       "conversations": 5
     },
     "lastSeen": {},
     "updatedAt": <current timestamp>
   }
   ```

4. Check if the badge appears in your app immediately (without restarting)

## Expected Result:
- You should see "5" badge on the Conversations menu item
- You should see a red dot on the hamburger menu button

## If it works:
The client-side integration is correct, and we just need to fix the Cloud Function deployment.

## Your User ID:
Check your Flutter console logs for: `✅ AttentionService initialized for user: {USER_ID}`
