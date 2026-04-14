# Category Taxonomy Migration Plan

## Goal
Create a category system that gives businesses a strong fit without overloading Home with too many chips.

## Strategy
- Keep Home category rail curated and short (8-10 categories + "More").
- Keep full catalog in Categories screen with search.
- Use layered taxonomy for listings:
  - Primary category (required)
  - Subcategory (required)
  - Tags (optional, up to 5)

## Proposed Primary Categories
1. Food & Beverage
2. Retail & Shopping
3. Beauty & Personal Care
4. Health & Wellness
5. Automotive
6. Home Services
7. Professional Services
8. Events & Entertainment
9. Travel & Tourism
10. Education & Training
11. Real Estate & Rentals
12. Technology & Electronics
13. Agriculture & Local Produce
14. Community & Nonprofit
15. Other

## Data Model
Use existing `categories` collection with optional hierarchy fields:
- slug: string
- title: string
- photo: string
- isActive: bool
- sortOrder: number
- parentSlug: string | null
- synonyms: string[]

## Listing Fields (non-breaking addition)
Add to listing documents:
- primaryCategorySlug: string
- subcategorySlug: string
- categoryTags: string[]

Keep existing fields for compatibility:
- categoryID
- categoryTitle

## Home UX Rules
- Show only primary categories.
- Show at most 8-10 cards/chips.
- Last chip/card is "More" to open full category browser.
- Sort order can be manually curated, then optimized by engagement.

## Migration Steps
1. Seed category docs for primary + subcategories (hierarchy via `parentSlug`).
2. Keep all current category reads as-is.
3. Add mapping from legacy category labels to primary category slugs.
4. Backfill existing listings:
   - If legacy category matches alias, set `primaryCategorySlug`.
   - If unknown, set `primaryCategorySlug = other`.
5. Update Add Listing flow to choose primary + subcategory.
6. Continue writing old and new fields during transition.
7. Remove dependence on old fields after migration confidence is high.

## Guardrails
- Do not block old listings from rendering.
- Do not require migration completion before shipping.
- Track unmapped categories and review weekly.

## Immediate Next Build Tasks
1. Add category search UI in Categories screen.
2. Add "More" entry in Home category rail.
3. Extend Add Listing screen with primary/subcategory selection.
4. Add analytics event for category selection quality.
