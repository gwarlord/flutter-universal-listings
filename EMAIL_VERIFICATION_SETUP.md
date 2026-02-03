# Email Verification Setup Guide

## Current Implementation

The app uses Firebase's default email verification system. Users must verify their email before accessing the app.

## Customizing Email Templates in Firebase Console

### Step 1: Access Email Templates
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (CaribTap)
3. Navigate to **Authentication** → **Templates** tab

### Step 2: Customize Email Verification Template
1. Find **Email address verification** in the template list
2. Click **Edit** (pencil icon)
3. You can customize:
   - **Sender name**: Change from "Firebase" to "CaribTap"
   - **Reply-to email**: Set your support email
   - **Subject line**: e.g., "Verify your CaribTap email"
   - **Email body**: Customize the message text
   - **Action button text**: The verification link button text

### Step 3: Customize the Verification Page (Optional)

For a custom branded verification page:

1. Go to **Authentication** → **Settings** → **Authorized domains**
2. Add your custom domain (e.g., `caribtap.com`)
3. Create a custom landing page on your domain
4. In **Templates**, update the action URL to point to your page
5. Your page should handle the email verification token

## Email Template Best Practices

- Keep the message short and clear
- Use your brand name consistently  
- Make the call-to-action prominent
- Include a note about link expiration
- Add support contact information

## Testing

After customizing:
1. Sign up with a new test email
2. Check the email formatting
3. Verify the link works properly
4. Test on different email clients

## Troubleshooting

### "Link has expired" error:
- Firebase verification links expire after **1 hour** by default
- This cannot be changed
- Users can request a new verification email by trying to log in again

### Full URL shows in email:
- Email clients display full links for security/anti-phishing protection
- This is standard email security behavior and cannot be hidden
- You can customize the button text and surrounding message

### Verification not working:
- Check that email is actually sent (check spam folder)
- Verify Firebase Authentication is enabled
- Check authorized domains in Firebase settings
- Ensure user's email is correct in Firebase Auth console

## Note on Firebase Dynamic Links

Firebase Dynamic Links (used for shorter custom URLs) were deprecated in August 2025 and are no longer supported. The app now uses Firebase's standard email verification system.
