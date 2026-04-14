# Category Taxonomy Runbook

This runbook applies the new category hierarchy to Firestore and backfills listings.

## Prerequisites

- Firebase project: `caribtap`
- Node runtime available
- Credentials via one of:
  - `--credentials /absolute/path/to/service-account.json`
  - `GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json`
  - Existing repo-root JSON: `caribtap-firebase-adminsdk-fbsvc-f2e46066e1.json`

## Optional: Isolated Admin Runtime

If root `node_modules` is unstable, install a clean runtime:

```bash
npm install --prefix temp/admin-runtime firebase-admin
export ADMIN_RUNTIME_NODE_MODULES="$PWD/temp/admin-runtime/node_modules"
```

## 1) Dry Run Taxonomy Sync

```bash
node tools/sync_category_taxonomy.js --project-id caribtap --credentials /absolute/path/to/service-account.json
```

What this does:
- Upserts canonical docs from `tools/category_taxonomy_seed.json`
- Populates real `slug` and `parentSlug` fields in Firestore categories
- Reports create/update/deactivate counts without writing

## 2) Apply Taxonomy Sync

```bash
node tools/sync_category_taxonomy.js --commit --deactivate-legacy --project-id caribtap --credentials /absolute/path/to/service-account.json
```

What this does:
- Writes canonical category docs
- Deactivates non-canonical active legacy categories

## 3) Dry Run Listing Backfill

```bash
node tools/migrate_listing_categories.js --project-id caribtap --credentials /absolute/path/to/service-account.json
```

What this does:
- Computes listing updates for:
  - `categoryID`
  - `categoryTitle`
  - `categoryPhoto`
  - `primaryCategorySlug`
  - `subcategorySlug`
- Reports unresolved listing count

## 4) Apply Listing Backfill

```bash
node tools/migrate_listing_categories.js --commit --deactivate-duplicates --project-id caribtap --credentials /absolute/path/to/service-account.json
```

What this does:
- Updates listing category fields
- Optionally deactivates duplicate category docs

## 5) Verify In App

- Restart app fully (not hot reload)
- Open Edit Listing category picker
- Confirm duplicates are gone
- Confirm hierarchy behavior appears once category docs include `parentSlug`
