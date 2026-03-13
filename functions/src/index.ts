import * as admin from "firebase-admin";

// Initialize Firebase Admin before any imports that use it
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Export all function modules
export * from "./email_verification";
export * from "./order_notifications";
export * from "./order_tracking";
export * from "./rental_booking_notifications";
export * from "./booking_notifications";
export * from "./user_suspension_notifications";
export * from "./listing_suspension_notifications";
export * from "./booking_reminders";
export * from "./listing_freshness";
export * from "./collaboration";
export * from "./tap_functions";
export * from "./deal_ad_notifications";
export * from "./chat_notifications";
export * from "./attention_tracking";
export * from "./tableMode";
export * from "./brand_functions";
export * from "./proof_of_payment_functions";
export * from "./photo_enhancement";
export * from "./ai_search/index";
export * from "./pro_docs/quote_acceptance";
export * from "./subscriptions";
export * from "./featured_functions";

// Note: Logic for onBookingCreated, onBookingUpdated, etc.
// is now contained within their respective source files (e.g., ./booking_notifications.ts)
// to avoid duplication and path mismatches.
