import { defineSecret } from "firebase-functions/params";
import sgMail from "@sendgrid/mail";
import { logger } from "firebase-functions";

// Define all secrets from Firebase Secret Manager
export const sendgridKeySecret = defineSecret("SENDGRID_KEY");
export const geminiKeySecret = defineSecret("GEMINI_KEY");
export const revenuecatKeySecret = defineSecret("REVENUECAT_KEY");
export const appUrlSecret = defineSecret("APP_URL");
export const appleSharedSecret = defineSecret("APPLE_SHARED_SECRET");
export const googleServiceAccountJsonSecret = defineSecret("GOOGLE_SERVICE_ACCOUNT_JSON");
export const entitlementTokenKeySecret = defineSecret("ENTITLEMENT_TOKEN_KEY");

/**
 * Initialize SendGrid with API key if available
 */
export async function initializeSendGrid(apiKey: string): Promise<void> {
  if (apiKey) {
    sgMail.setApiKey(apiKey);
  } else {
    logger.warn("SendGrid API key not configured");
  }
}

/**
 * Send email using SendGrid
 */
export async function sendEmail(
  to: string,
  subject: string,
  html: string,
  apiKey: string
): Promise<void> {
  if (!apiKey) {
    logger.warn("SendGrid key not set, skipping email", { to, subject });
    return;
  }

  try {
    await sgMail.send({
      to,
      from: { email: "admin@caribtap.com", name: "CaribTap" },
      subject,
      html,
    });
    logger.info("Email sent successfully", { to, subject });
  } catch (error) {
    logger.error("Failed to send email", { to, subject, error });
    throw error;
  }
}
