"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
const admin = __importStar(require("firebase-admin"));
// Initialize Firebase Admin before any imports that use it
if (admin.apps.length === 0) {
    admin.initializeApp();
}
// Export all function modules
__exportStar(require("./email_verification"), exports);
__exportStar(require("./order_notifications"), exports);
__exportStar(require("./order_tracking"), exports);
__exportStar(require("./rental_booking_notifications"), exports);
__exportStar(require("./booking_notifications"), exports);
__exportStar(require("./user_suspension_notifications"), exports);
__exportStar(require("./listing_suspension_notifications"), exports);
__exportStar(require("./booking_reminders"), exports);
__exportStar(require("./listing_freshness"), exports);
__exportStar(require("./collaboration"), exports);
__exportStar(require("./tap_functions"), exports);
__exportStar(require("./deal_ad_notifications"), exports);
__exportStar(require("./chat_notifications"), exports);
__exportStar(require("./attention_tracking"), exports);
__exportStar(require("./tableMode"), exports);
__exportStar(require("./brand_functions"), exports);
__exportStar(require("./proof_of_payment_functions"), exports);
__exportStar(require("./photo_enhancement"), exports);
__exportStar(require("./ai_search/index"), exports);
__exportStar(require("./pro_docs/quote_acceptance"), exports);
__exportStar(require("./subscriptions"), exports);
__exportStar(require("./featured_functions"), exports);
// Note: Logic for onBookingCreated, onBookingUpdated, etc.
// is now contained within their respective source files (e.g., ./booking_notifications.ts)
// to avoid duplication and path mismatches.
