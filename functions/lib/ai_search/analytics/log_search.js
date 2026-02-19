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
Object.defineProperty(exports, "__esModule", { value: true });
exports.aggregateDailyCosts = void 0;
exports.logSearchEvent = logSearchEvent;
exports.getAnalyticsSummary = getAnalyticsSummary;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
/**
 * Log search analytics event
 * Called after each search operation
 */
async function logSearchEvent(event) {
    try {
        await db.collection("search_analytics").add({
            ...event,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Also log cost if applicable
        if (event.eventType === "query_interpreted") {
            await logQueryCost(event.userId, event.tier || "free");
        }
    }
    catch (error) {
        functions.logger.warn("Failed to log search event", { error });
    }
}
/**
 * Log AI query cost (track spending on Gemini API)
 * Rough estimate: ~$0.00001 per query
 */
async function logQueryCost(userId, tier) {
    try {
        const estimatedCost = 0.00001; // in USD
        const today = new Date().toISOString().split("T")[0];
        const costDocId = `cost_${today}`;
        await db
            .collection("search_costs")
            .doc(costDocId)
            .update({
            [`users.${userId}`]: admin.firestore.FieldValue.increment(estimatedCost),
            totalCost: admin.firestore.FieldValue.increment(estimatedCost),
            queriesByTier: {
                [tier]: admin.firestore.FieldValue.increment(1),
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        })
            .catch(async () => {
            // Document doesn't exist, create it
            const byTier = {};
            byTier[tier] = 1;
            await db.collection("search_costs").doc(costDocId).set({
                date: today,
                users: { [userId]: estimatedCost },
                totalCost: estimatedCost,
                queriesByTier: byTier,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        });
    }
    catch (error) {
        functions.logger.warn("Failed to log query cost", { error });
    }
}
/**
 * Aggregate daily costs (scheduled daily)
 * Run at 11:59 PM UTC via Cloud Scheduler
 */
exports.aggregateDailyCosts = functions.pubsub
    .schedule("59 23 * * *")
    .timeZone("UTC")
    .onRun(async () => {
    try {
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        const dateStr = yesterday.toISOString().split("T")[0];
        const costDoc = await db.collection("search_costs").doc(`cost_${dateStr}`).get();
        if (!costDoc.exists) {
            functions.logger.info("No costs recorded for date", { dateStr });
            return;
        }
        const costData = costDoc.data();
        // Calculate summary
        const queriesByTier = costData?.queriesByTier || {};
        const queriesProcessed = Object.values(queriesByTier).reduce((a, b) => a + (typeof b === 'number' ? b : 0), 0);
        const summary = {
            date: dateStr,
            totalCost: costData?.totalCost || 0,
            queriesProcessed,
            resultsReturned: 0, // Would need to aggregate from analytics
            cacheHits: 0, // Would need to track separately
            errors: 0, // Would need to count from analytics
        };
        // Store summary
        await db.collection("search_analytics_summary").doc(dateStr).set(summary);
        // Check for cost alerts
        if (summary.totalCost > 50) {
            functions.logger.warn("Daily costs exceeded $50 threshold", {
                date: dateStr,
                totalCost: summary.totalCost,
            });
            // Could send alert email here
        }
        functions.logger.info("Daily costs aggregated", { summary });
    }
    catch (error) {
        functions.logger.error("Failed to aggregate costs", { error });
    }
});
/**
 * Get analytics summary for a date range
 * Used by admin dashboard
 */
async function getAnalyticsSummary(startDate, endDate) {
    try {
        const snapshot = await db
            .collection("search_analytics")
            .where("timestamp", ">=", new Date(startDate))
            .where("timestamp", "<=", new Date(endDate))
            .get();
        const events = snapshot.docs.map((doc) => doc.data());
        const queries = events.filter((e) => e.eventType === "query_interpreted");
        const completions = events.filter((e) => e.eventType === "search_completed");
        const errors = events.filter((e) => e.eventType === "error");
        const latencies = completions
            .map((e) => e.latency || 0)
            .filter((l) => l > 0);
        const avgLatency = latencies.length > 0
            ? latencies.reduce((a, b) => a + b, 0) / latencies.length
            : 0;
        // Get top queries
        const queryMap = new Map();
        queries.forEach((e) => {
            if (e.query) {
                queryMap.set(e.query, (queryMap.get(e.query) || 0) + 1);
            }
        });
        const topQueries = Array.from(queryMap.entries())
            .sort((a, b) => b[1] - a[1])
            .slice(0, 10)
            .map(([q]) => q);
        return {
            totalQueries: queries.length,
            totalResults: completions.reduce((sum, e) => sum + (e.resultCount || 0), 0),
            avgLatency,
            topQueries,
            errorRate: events.length > 0 ? errors.length / events.length : 0,
        };
    }
    catch (error) {
        functions.logger.error("Failed to get analytics summary", { error });
        return {
            totalQueries: 0,
            totalResults: 0,
            avgLatency: 0,
            topQueries: [],
            errorRate: 0,
        };
    }
}
