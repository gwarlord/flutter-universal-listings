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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupExpiredCodes = exports.verifyEmailCode = exports.sendVerificationCode = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const mail_1 = __importDefault(require("@sendgrid/mail"));
// Initialize SendGrid (you'll need to set this API key in Firebase config)
// Run: firebase functions:config:set sendgrid.key="YOUR_SENDGRID_API_KEY"
const SENDGRID_API_KEY = functions.config().sendgrid?.key;
if (SENDGRID_API_KEY) {
    mail_1.default.setApiKey(SENDGRID_API_KEY);
}
// Generate a 6-digit verification code
function generateVerificationCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}
// Send verification code via email
exports.sendVerificationCode = functions.https.onCall(async (data, context) => {
    // Check if user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const userId = context.auth.uid;
    const email = data.email || context.auth.token.email;
    if (!email) {
        throw new functions.https.HttpsError('invalid-argument', 'Email is required');
    }
    // Rate limiting: Check if user has requested too many codes recently
    const recentCodesQuery = await admin.firestore()
        .collection('email_verifications')
        .where('userId', '==', userId)
        .where('createdAt', '>', admin.firestore.Timestamp.fromMillis(Date.now() - 3600000)) // Last hour
        .get();
    if (recentCodesQuery.size >= 3) {
        throw new functions.https.HttpsError('resource-exhausted', 'Too many verification attempts. Please try again later.');
    }
    // Generate verification code
    const code = generateVerificationCode();
    const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 600000); // 10 minutes
    // Store verification code in Firestore
    const verificationRef = await admin.firestore().collection('email_verifications').add({
        userId,
        email,
        code,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt,
        verified: false,
        attempts: 0,
    });
    // Send email with verification code
    try {
        if (SENDGRID_API_KEY) {
            // Using SendGrid
            const msg = {
                to: email,
                from: 'noreply@caribtap.com', // Change to your verified sender
                subject: 'CaribTap - Email Verification Code',
                text: `Your verification code is: ${code}\n\nThis code will expire in 10 minutes.\n\nIf you didn't request this code, please ignore this email.`,
                html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <h2 style="color: #333;">CaribTap Email Verification</h2>
            <p style="font-size: 16px; color: #555;">Your verification code is:</p>
            <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
              <h1 style="color: #007bff; font-size: 36px; letter-spacing: 8px; margin: 0;">${code}</h1>
            </div>
            <p style="font-size: 14px; color: #888;">This code will expire in 10 minutes.</p>
            <p style="font-size: 14px; color: #888;">If you didn't request this code, please ignore this email.</p>
          </div>
        `,
            };
            await mail_1.default.send(msg);
        }
        else {
            // Fallback: Log the code (for development/testing only)
            console.log(`📧 Verification code for ${email}: ${code}`);
            // In production without SendGrid, you could use Firebase Extensions:
            // - Trigger Email extension
            // - Or implement your own email service
        }
        return {
            success: true,
            message: 'Verification code sent successfully',
            verificationId: verificationRef.id,
        };
    }
    catch (error) {
        console.error('Error sending verification email:', error);
        // Delete the verification record if email failed
        await verificationRef.delete();
        throw new functions.https.HttpsError('internal', 'Failed to send verification email');
    }
});
// Verify the code entered by the user
exports.verifyEmailCode = functions.https.onCall(async (data, context) => {
    // Check if user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const userId = context.auth.uid;
    const { code } = data;
    if (!code || typeof code !== 'string' || code.length !== 6) {
        throw new functions.https.HttpsError('invalid-argument', 'Valid 6-digit code is required');
    }
    // Find the verification record
    const verificationsQuery = await admin.firestore()
        .collection('email_verifications')
        .where('userId', '==', userId)
        .where('code', '==', code)
        .where('verified', '==', false)
        .orderBy('createdAt', 'desc')
        .limit(1)
        .get();
    if (verificationsQuery.empty) {
        throw new functions.https.HttpsError('not-found', 'Invalid verification code');
    }
    const verificationDoc = verificationsQuery.docs[0];
    const verification = verificationDoc.data();
    // Check if code is expired
    const now = admin.firestore.Timestamp.now();
    if (verification.expiresAt < now) {
        throw new functions.https.HttpsError('deadline-exceeded', 'Verification code has expired');
    }
    // Check attempt limit
    if (verification.attempts >= 5) {
        throw new functions.https.HttpsError('resource-exhausted', 'Too many attempts. Please request a new code.');
    }
    // Increment attempt counter
    await verificationDoc.ref.update({
        attempts: admin.firestore.FieldValue.increment(1),
    });
    // Mark as verified in Firestore
    await verificationDoc.ref.update({
        verified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Update Firebase Auth to mark email as verified
    await admin.auth().updateUser(userId, {
        emailVerified: true,
    });
    // Also update the user document in Firestore if you're tracking it there
    try {
        await admin.firestore().collection('users').doc(userId).update({
            emailVerified: true,
            emailVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (error) {
        console.error('Error updating user document:', error);
        // Don't throw - verification still succeeded
    }
    return {
        success: true,
        message: 'Email verified successfully',
    };
});
// Cleanup expired verification codes (run daily)
exports.cleanupExpiredCodes = functions.pubsub
    .schedule('every 24 hours')
    .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const expiredQuery = await admin.firestore()
        .collection('email_verifications')
        .where('expiresAt', '<', now)
        .get();
    const batch = admin.firestore().batch();
    expiredQuery.docs.forEach(doc => {
        batch.delete(doc.ref);
    });
    await batch.commit();
    console.log(`Deleted ${expiredQuery.size} expired verification codes`);
    return null;
});
