/// Constants for the Tap (Vouch) feature

/// Firestore collection names
const String tapsSubcollection = 'taps';

/// Tap badge thresholds
const int tapBadgeThresholdVouched = 10;
const int tapBadgeThresholdVerified = 50;

/// Abuse prevention constants
const int minAccountAgeMinutesForTap = 10;
const int tapSpamPreventionDelaySeconds = 5; // Minimum delay between tap/untap actions

/// UI strings
const String tapButtonText = 'Tap to Vouch';
const String untapButtonText = 'Untap';
const String tapDialogTitle = 'Vouch for this business?';
const String tapDialogMessage = 'A Tap means "I know this business / they are legit".\n\nThis helps others find trustworthy listings.';
const String tapSuccessMessage = 'Thanks for vouching!';
const String untapSuccessMessage = 'Tap removed';

/// Error messages
const String tapErrorOwnListing = 'You cannot tap your own listing';
const String tapErrorNotAuthenticated = 'Please sign in to vouch for listings';
const String tapErrorEmailNotVerified = 'Please verify your email to vouch for listings';
const String tapErrorAccountTooNew = 'Account must be at least 10 minutes old to vouch';
const String tapErrorTooQuick = 'Please wait a moment before tapping/untapping again';
const String tapErrorGeneral = 'Failed to tap. Please try again.';
