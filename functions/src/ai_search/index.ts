import * as functions from "firebase-functions/v1";

// Export the new, corrected search interpreter function
export * from "./interpretation/search_interpreter";

// Export the other existing AI search functions
export * from "./retrieval/search_listings";
export * from "./rate_limiting/rate_limiter";
export * from "./rate_limiting/abuse_detector";
export * from "./analytics/log_search";

// Log initialization
functions.logger.info("AI Search functions initialized");
