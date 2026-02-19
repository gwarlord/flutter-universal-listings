# Firebase Secret Manager Migration Checklist

## Pre-Deployment Checklist

- [ ] Review migration guide: `MIGRATION_TO_SECRET_MANAGER.md`
- [ ] Backup current `functions/lib` directory
- [ ] Have all API keys ready:
  - [ ] SendGrid API key
  - [ ] Gemini API key
  - [ ] RevenueCat API key
  - [ ] App URL (optional)

## Setting Up Secrets

- [ ] Authenticate with Firebase CLI: `firebase login`
- [ ] Set SendGrid key: `firebase functions:secrets:set sendgrid_key --projectId YOUR_PROJECT_ID`
- [ ] Set Gemini key: `firebase functions:secrets:set gemini_key --projectId YOUR_PROJECT_ID`
- [ ] Set RevenueCat key: `firebase functions:secrets:set revenuecat_key --projectId YOUR_PROJECT_ID`
- [ ] Set App URL: `firebase functions:secrets:set app_url --projectId YOUR_PROJECT_ID`
- [ ] Verify secrets are set: `firebase functions:secrets:list --projectId YOUR_PROJECT_ID`

## Building & Testing Locally

- [ ] Install dependencies: `npm install`
- [ ] Build TypeScript: `npm run build`
- [ ] Check for build errors
- [ ] Test with emulator: `firebase emulators:start`
- [ ] Verify functions load without errors
- [ ] Test at least one function that uses secrets

## Deployment

- [ ] Run lint check: `npm run lint`
- [ ] Final build: `npm run build`
- [ ] Deploy functions: `npm run deploy`
- [ ] Monitor deployment logs
- [ ] Wait for deployment to complete successfully

## Post-Deployment Verification

- [ ] Check Firebase Console > Functions
- [ ] All functions show status = OK
- [ ] Review Function logs for errors
- [ ] Test key functions from Firebase Console
- [ ] Monitor error rates for 24 hours
- [ ] Verify no `functions.config()` calls in logs

## Rollback Plan (if needed)

- [ ] Save current state with git: `git tag pre-secret-migration`
- [ ] If issues arise, redeploy from previous git commit
- [ ] Keep old config values in Firebase until confirmed working

## Files Changed Summary

### Core Changes
- `src/common/secrets.ts` - **NEW** - Centralized secrets
- `src/index.ts` - Removed inline sendEmail, updated imports
- `src/email_verification.ts` - Updated to use secrets
- `src/order_tracking.ts` - Updated to use secrets
- `src/listing_freshness.ts` - Updated to use secrets
- `src/booking_reminders.ts` - Updated to use secrets
- `src/collaboration.ts` - Updated to use secrets
- `src/tableMode.ts` - Updated to use secrets
- `src/ai_search/interpretation/interpret_query.ts` - Updated to use secrets

### Auto-Generated (will be regenerated on build)
- All files in `lib/` directory - Will update during compilation

## Key Changes to Remember

1. **All secret access is now async**:
   ```typescript
   // Old: const key = functions.config().sendgrid?.key;
   // New: const key = await sendgridKeySecret.value();
   ```

2. **Import changes**:
   ```typescript
   // Old: import * as functions from "firebase-functions/v1";
   // New: import * as functions from "firebase-functions";
   ```

3. **Secrets are centralized** in `src/common/secrets.ts`

## Support & Resources

- Migration Docs: https://firebase.google.com/docs/functions/config-env#migrate-config
- Secret Manager: https://firebase.google.com/docs/functions/config-env
- Params API: https://firebase.google.com/docs/functions/params

## Important Dates

- **NOW**: Deploy migrated code with secrets
- **March 2026**: Runtime Config (old system) will shut down
- **Before March 2026**: All apps must have migrated

---

**Status**: ✅ Code migration completed
**Next Step**: Set secrets in Firebase and deploy
