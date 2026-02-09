# Reviews Pagination - Firestore Index

## Required Composite Index

The reviews pagination feature requires a composite index in Firestore for efficient querying.

### Index Configuration

**Collection:** `reviews` (or as configured in `cfg.reviewCollection`)

**Fields:**
- `listingID` (Ascending)
- `createdAt` (Descending)

### How to Create

When you first run the app and navigate to the reviews section, Firestore will automatically detect the missing index and provide a direct link in the console error message. Click that link to auto-create the index.

Alternatively, add this to `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "reviews",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "listingID",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    }
  ]
}
```

Then deploy with:
```bash
firebase deploy --only firestore:indexes
```

## Query Details

The pagination uses:
```dart
firestore
  .collection('reviews')
  .where('listingID', isEqualTo: listingID)
  .orderBy('createdAt', descending: true)
  .limit(limit)
  .startAfter([cursor])
```

This returns reviews for a specific listing, ordered by newest first, with cursor-based pagination for infinite scroll.
