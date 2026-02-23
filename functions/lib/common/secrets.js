"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.entitlementTokenKeySecret = exports.googleServiceAccountJsonSecret = exports.appleSharedSecret = exports.appUrlSecret = exports.revenuecatKeySecret = exports.geminiKeySecret = exports.sendgridKeySecret = void 0;
exports.initializeSendGrid = initializeSendGrid;
exports.sendEmail = sendEmail;
const params_1 = require("firebase-functions/params");
const mail_1 = __importDefault(require("@sendgrid/mail"));
const firebase_functions_1 = require("firebase-functions");
// Define all secrets from Firebase Secret Manager
exports.sendgridKeySecret = (0, params_1.defineSecret)("SENDGRID_KEY");
exports.geminiKeySecret = (0, params_1.defineSecret)("GEMINI_KEY");
exports.revenuecatKeySecret = (0, params_1.defineSecret)("REVENUECAT_KEY");
exports.appUrlSecret = (0, params_1.defineSecret)("APP_URL");
exports.appleSharedSecret = (0, params_1.defineSecret)("APPLE_SHARED_SECRET");
exports.googleServiceAccountJsonSecret = (0, params_1.defineSecret)("GOOGLE_SERVICE_ACCOUNT_JSON");
exports.entitlementTokenKeySecret = (0, params_1.defineSecret)("ENTITLEMENT_TOKEN_KEY");
/**
 * Initialize SendGrid with API key if available
 */
async function initializeSendGrid(apiKey) {
    if (apiKey) {
        mail_1.default.setApiKey(apiKey);
    }
    else {
        firebase_functions_1.logger.warn("SendGrid API key not configured");
    }
}
/**
 * Send email using SendGrid
 */
async function sendEmail(to, subject, html, apiKey) {
    if (!apiKey) {
        firebase_functions_1.logger.warn("SendGrid key not set, skipping email", { to, subject });
        return;
    }
    try {
        await mail_1.default.send({
            to,
            from: { email: "admin@caribtap.com", name: "CaribTap" },
            subject,
            html,
        });
        firebase_functions_1.logger.info("Email sent successfully", { to, subject });
    }
    catch (error) {
        firebase_functions_1.logger.error("Failed to send email", { to, subject, error });
        throw error;
    }
}
