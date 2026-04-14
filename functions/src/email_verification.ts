import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import sgMail from '@sendgrid/mail';
import { sendgridKeySecret } from './common/secrets';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

// Generate a 6-digit verification code
function generateVerificationCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Send verification code via email
export const sendVerificationCode = functions.runWith({ secrets: [sendgridKeySecret] }).https.onCall(async (data, context) => {
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
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Too many verification attempts. Please try again later.'
    );
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
    const sendgridKey = await sendgridKeySecret.value();
    if (sendgridKey) {
      // Using SendGrid
      sgMail.setApiKey(sendgridKey);
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
      await sgMail.send(msg);
    } else {
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
  } catch (error) {
    console.error('Error sending verification email:', error);
    
    // Delete the verification record if email failed
    await verificationRef.delete();
    
    throw new functions.https.HttpsError('internal', 'Failed to send verification email');
  }
});

// Send password reset email with a CTA button.
// This uses Firebase Admin to generate the action link and SendGrid for HTML rendering.
export const sendPasswordResetEmailButton = functions.runWith({ secrets: [sendgridKeySecret] }).https.onCall(async (data) => {
  const email = (data?.email ?? '').toString().trim().toLowerCase();
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }

  // Always return success-like responses for unknown users to reduce account enumeration risk.
  try {
    const actionCodeSettings: admin.auth.ActionCodeSettings = {
      url: 'https://caribtap.com/reset-password',
      handleCodeInApp: true,
      iOS: {
        bundleId: 'com.caribtap.ios',
      },
      android: {
        packageName: 'com.caribtap.instaflutter.android',
        installApp: true,
        minimumVersion: '1',
      },
    };

    const resetLink = await admin.auth().generatePasswordResetLink(
      email,
      actionCodeSettings,
    );

    const sendgridKey = await sendgridKeySecret.value();
    if (!sendgridKey) {
      console.warn('SENDGRID_KEY is not configured; skipping custom reset email send.');
      return {
        success: true,
        customEmailSent: false,
        message: 'If an account exists for this email, a reset link has been sent.',
      };
    }

    sgMail.setApiKey(sendgridKey);
    await sgMail.send({
      to: email,
      from: { email: 'noreply@caribtap.com', name: 'CaribTap' },
      subject: 'Reset your password for CaribTap',
      text:
        `We received a request to reset your CaribTap password.\n\n` +
        `Reset password: ${resetLink}\n\n` +
        `If you did not request this, you can safely ignore this email.`,
      html: `
        <div style="font-family: Arial, Helvetica, sans-serif; max-width: 620px; margin: 0 auto; padding: 24px; color: #1f2937;">
          <h2 style="margin: 0 0 16px; color: #0f172a;">Reset your password for CaribTap</h2>
          <p style="margin: 0 0 18px; line-height: 1.5;">We received a request to reset your password.</p>
          <p style="margin: 0 0 24px; line-height: 1.5;">Click the button below to continue:</p>
          <p style="margin: 0 0 28px;">
            <a href="${resetLink}" style="display: inline-block; background: #2A9EB8; color: #ffffff; text-decoration: none; padding: 12px 22px; border-radius: 10px; font-weight: 700;">
              Reset Password
            </a>
          </p>
          <p style="margin: 0 0 12px; font-size: 13px; color: #6b7280; line-height: 1.5;">
            If the button does not work, copy and paste this link into your browser:
          </p>
          <p style="margin: 0 0 16px; font-size: 12px; color: #6b7280; word-break: break-word;">${resetLink}</p>
          <p style="margin: 0; font-size: 12px; color: #6b7280;">If you did not request this, you can safely ignore this email.</p>
        </div>
      `,
    });

    return {
      success: true,
      customEmailSent: true,
      message: 'If an account exists for this email, a reset link has been sent.',
    };
  } catch (error: any) {
    const code = error?.code || '';
    if (code === 'auth/user-not-found') {
      return {
        success: true,
        message: 'If an account exists for this email, a reset link has been sent.',
      };
    }

    console.error('sendPasswordResetEmailButton error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send password reset email');
  }
});

// Verify the code entered by the user
export const verifyEmailCode = functions.https.onCall(async (data, context) => {
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
  } catch (error) {
    console.error('Error updating user document:', error);
    // Don't throw - verification still succeeded
  }

  return {
    success: true,
    message: 'Email verified successfully',
  };
});

// Cleanup expired verification codes (run daily)
export const cleanupExpiredCodes = functions.pubsub
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
