# CaribTap AI-Assisted Search - UX & UI Design

**Version:** 1.0  
**Status:** Production-Ready Design  
**Last Updated:** February 18, 2026

---

## Table of Contents

1. [User Flows](#user-flows)
2. [Screen Specifications](#screen-specifications)
3. [Component Library](#component-library)
4. [Interaction Patterns](#interaction-patterns)
5. [Empty States & Error Handling](#empty-states--error-handling)
6. [Accessibility](#accessibility)
7. [Localization](#localization)

---

## User Flows

### Flow 1: Basic AI Search

```
User opens app
  → Taps search icon (magnifying glass)
  → SearchEntryScreen appears
  → User types "barber near Gulf City"
  → As they type, shows recent searches below
  → User taps search or Enter
  → Shows loading indicator with "Understanding your search..."
  → SearchResultsScreen appears
  → Filter chips shown: "📍 Gulf City", "✂️ Barber", "Near you"
  → Results listed with explanation chips
  → User taps a listing
  → ListingDetailsScreen (existing)
```

### Flow 2: Conversational Refinement

```
User on SearchResultsScreen with results
  → User taps "Refine" field at top
  → Types "only delivery"
  → Presses Enter
  → Loading indicator
  → Results refresh with new filter chip: "🚚 Delivery"
  → Previous filters remain: "📍 Gulf City", "✂️ Barber"
  → Results updated
```

### Flow 3: Empty State Rescue

```
User searches "luxury yacht rental Mayaro"
  → No results found
  → EmptyStateWidget appears with:
    - "No results found"
    - "Try broadening your search:"
    - Button: "Search within 20km of Mayaro"
    - Button: "Show all boat rentals in Trinidad"
    - Alternate suggestions: "luxury car rental", "boat tours Mayaro"
  → User taps "Search within 20km"
  → New search with broadened radius
  → Results appear
```

### Flow 4: Saved Search

```
User on SearchResultsScreen with good results
  → User taps "Save Search" icon (bookmark with +)
  → Dialog: "Save this search?"
    - Text field: "Name this search" (pre-filled: "Barber near Gulf City")
    - Toggle: "🔔 Notify me of new matches" (default: OFF)
  → User enables toggle, taps "Save"
  → Toast: "Search saved! You'll be notified of new matches."
  → Search appears in "Saved Searches" screen (accessible from profile)
```

### Flow 5: Location Permission

```
User searches "pizza near me"
  → If location denied or not requested:
    → BottomSheet: "Enable location for 'near me' searches"
      - "CaribTap uses your location to find nearby listings"
      - Button: "Enable Location"
      - Button: "Search without location"
  → If user taps "Enable Location":
    → System permission dialog
  → If granted:
    → Search executes with user's location
  → If denied:
    → Search executes based on query intent (defaults to country)
```

---

## Screen Specifications

### 1. SearchEntryScreen

**Purpose**: Entry point for all searches; accessed from home screen or nav bar.

**Layout**:
```
┌────────────────────────────────────────────┐
│ ← [Back]        Search        [Filters 🎛️] │ ← AppBar
├────────────────────────────────────────────┤
│                                            │
│  ┌─────────────────────────────────────┐  │
│  │ 🔍 Search listings, deals...        │  │ ← Search TextField
│  └─────────────────────────────────────┘  │
│                                            │
│  💡 Try: "barber near Gulf City open now"  │ ← Suggestion chip
│  💡 Try: "party supplies delivery"         │
│  💡 Try: "cheapest car rental Tobago"      │
│                                            │
│  ─────────── Recent Searches ───────────   │
│  🕑 barber Port of Spain                   │ ← Tappable
│  🕑 electronics with vouched sellers       │
│  🕑 gym membership deals                   │
│                                            │
│  ─────────── Content Type ─────────────    │
│  ☐ All (default)                           │ ← Checkboxes
│  ☐ Listings only                           │
│  ☐ Deals only                              │
│                                            │
│  ─────────── Saved Searches ───────────    │
│  ⭐ Barber near Gulf City (🔔)             │ ← Tappable
│  ⭐ Party supplies under $500              │
│                                            │
└────────────────────────────────────────────┘
```

**Components**:
- **AppBar**: 
  - Left: Back button
  - Center: "Search"
  - Right: Filters icon (opens FiltersScreen with advanced options: price range, category, radius manually)
- **Search TextField**:
  - Placeholder: "Search listings, deals..."
  - Autofocus: true
  - Clear button (X) when text present
  - On submit: Trigger AI search
- **Suggestion Chips** (3-5 rotating):
  - Hardcoded examples relevant to Trinidad/Tobago
  - Tappable: Fills search field
- **Recent Searches** (last 5):
  - Local storage (SharedPreferences)
  - Tappable: Re-executes search
  - Swipe-to-delete
- **Content Type Toggle**:
  - Radio buttons: All / Listings / Deals
  - Default: All
- **Saved Searches** (if any):
  - Fetched from Firestore `users/{uid}/saved_searches`
  - Shows notification bell if alerts enabled
  - Tappable: Executes saved search

**Interactions**:
- Typing in search field:
  - Shows recent searches below
  - Debounced autocomplete suggestions (optional, Phase 2)
- Tapping suggestion chip:
  - Fills search field, user can edit, then tap search
- Tapping recent search:
  - Immediately executes search
- Tapping saved search:
  - Immediately executes search WITH saved filters

**State**:
- `SearchEntryState`:
  - `loading: false`
  - `recentSearches: List<String>`
  - `savedSearches: List<SavedSearch>`

---

### 2. SearchResultsScreen

**Purpose**: Display search results with explainable filters and refinement input.

**Layout**:
```
┌─────────────────────────────────────────────┐
│ ← [Back]   🔍 barber Gulf City    ⋮ [More]  │ ← AppBar
├─────────────────────────────────────────────┤
│                                             │
│  ╔═══════════════════════════════════════╗ │
│  ║ 🔍 Refine this search...              ║ │ ← Refinement Input
│  ╚═══════════════════════════════════════╝ │
│                                             │
│  ┌──────── Filter Chips (scrollable) ────┐ │
│  │ 📍 Gulf City ⓧ  ✂️ Barber ⓧ           │ ← Editable chips
│  │ ⭐ Top rated     🔵 Vouched            │
│  └─────────────────────────────────────────┘ │
│                                             │
│  ℹ️ Why these results? [Tap to see]        │ ← Explanation link
│                                             │
│  ─────── Sort: Relevance ▼ ───────         │ ← Sort dropdown
│    • Relevance                              │   (Relevance, Distance,
│    • Distance                               │    Top rated, Price,
│    • Top rated                              │    Ending soon for deals)
│    • Price: Low to High                     │
│    • Ending soon (for deals)                │
│                                             │
│  ┌────────────────────────────────────┐    │
│  │ 🖼️ [Image]    Classic Cuts Barber │    │ ← Result Card
│  │                                    │    │
│  │ ⭐ 4.8 · 23 reviews · 2.1 km      │    │
│  │ 📍 Gulf City Mall                  │    │
│  │ 💰 $50 - $100                      │    │
│  │                                    │    │
│  │ 🔵 Vouched · Near you · Top rated │    │ ← Explanation chips
│  └────────────────────────────────────┘    │
│                                             │
│  ┌────────────────────────────────────┐    │
│  │ 🖼️ [Image]    Tony's Barbershop   │    │
│  │ ⭐ 4.5 · 12 reviews · 3.8 km      │    │
│  │ ...                                │    │
│  └────────────────────────────────────┘    │
│                                             │
│  [Load More]                                │ ← Pagination
│                                             │
└─────────────────────────────────────────────┘
```

**Components**:
- **AppBar**:
  - Left: Back button
  - Center: Query summary (e.g., "barber Gulf City")
  - Right: More menu (⋮):
    - "Save this search"
    - "Share results"
    - "Report issue"
- **Refinement Input**:
  - Single-line TextField
  - Placeholder: "🔍 Refine this search..."
  - On submit: Sends refinement text to AI interpretation (appends to previous query context)
- **Filter Chips** (horizontally scrollable):
  - Generated from AI interpretation + user selections
  - Each chip has (ⓧ) to remove
  - Tappable to edit (e.g., location radius)
  - Examples:
    - `📍 Gulf City` → Tap to change location
    - `✂️ Barber` → Tap to change category
    - `⭐ Top rated` → Tap to remove
    - `💰 Under $500` → Tap to edit price range
    - `🚚 Delivery` → Tap to remove
    - `🔵 Vouched` → Tap to remove
    - `⏰ Open now` → Tap to remove
- **"Why these results?" Link**:
  - Opens BottomSheet with detailed explanation
- **Sort Dropdown**:
  - Options depend on content type:
    - Listings: Relevance, Distance, Top rated, Price
    - Deals: Relevance, Ending soon, Savings, Top rated
- **Result Cards**:
  - Listing card (existing design, enhanced):
    - Image, title, rating, reviews, distance, price
    - **NEW**: Explanation chips row at bottom
  - Deal card (existing design, enhanced):
    - Media, caption, countdown, redemption count
    - **NEW**: Explanation chips row
- **Pagination**:
  - "Load More" button OR infinite scroll
  - Loads 20 results at a time

**Interactions**:
- Tapping Filter Chip ⓧ:
  - Removes filter
  - Re-queries (local filter, no AI re-interpretation)
- Tapping Filter Chip (not ⓧ):
  - Opens edit dialog (e.g., location picker, price slider)
- Typing in Refinement Input + Enter:
  - Shows loading overlay
  - Calls AI interpretation with context
  - Updates filters and results
- Tapping "Why these results?":
  - Opens `ExplanationBottomSheet`
- Tapping Result Card:
  - Navigates to ListingDetailsScreen or DealDetailScreen (existing)
- Changing Sort:
  - Re-sorts current results (client-side if possible, else re-query)

**State**:
- `SearchResultsState`:
  - `loading: bool`
  - `query: String`
  - `filters: SearchFilters` (structured)
  - `results: List<ListingModel | DealAdModel>`
  - `explanation: SearchExplanation`
  - `sortBy: SortOption`
  - `hasMore: bool`
  - `page: int`

---

### 3. ExplanationBottomSheet

**Purpose**: Show detailed reasoning for search results.

**Layout**:
```
┌─────────────────────────────────────────────┐
│         Why these results?           [Close]│ ← Header
├─────────────────────────────────────────────┤
│                                             │
│  🤖 AI understood your query:               │
│  "barber near Gulf City open now"           │
│                                             │
│  ✅ Category: Barber / Hair Salons          │
│  ✅ Location: Gulf City, San Fernando       │
│  ✅ Radius: 5 km                            │
│  ✅ Must be open now (Saturday 2pm)         │
│                                             │
│  📊 Results ranked by:                      │
│  1. Distance from your location             │
│  2. Review rating (⭐ 4.5+)                 │
│  3. Vouch badge (trusted sellers)           │
│  4. Recency (updated recently)              │
│                                             │
│  💡 Tips to refine:                         │
│  • Try "only male barbers"                  │
│  • Try "cheapest barber"                    │
│  • Try "barber with parking"                │
│                                             │
└─────────────────────────────────────────────┘
```

**Components**:
- **AI Interpretation Section**:
  - Shows parsed query
  - Lists extracted filters with ✅
- **Ranking Explanation**:
  - Lists top 3-4 ranking signals
- **Refinement Suggestions**:
  - 3-5 hardcoded or AI-generated suggestions

**Interactions**:
- Tapping a suggestion:
  - Closes sheet
  - Fills refinement input with suggestion
  - User can edit and submit

---

### 4. EmptyStateWidget

**Purpose**: Handle zero-result scenarios gracefully.

**Scenarios**:

#### Scenario A: Zero Results (Strict Query)

```
┌─────────────────────────────────────────────┐
│             No results found                │
│                                             │
│  😔 We couldn't find any                    │
│     "luxury yacht rental Mayaro"            │
│                                             │
│  Try these instead:                         │
│                                             │
│  🔍 Search within 20km of Mayaro            │ ← Button
│  🔍 Show all boat rentals in Trinidad       │ ← Button
│                                             │
│  ──────── Suggested Searches ────────       │
│  • luxury car rental                        │ ← Tappable
│  • boat tours Mayaro                        │
│  • yacht rental Trinidad                    │
│                                             │
└─────────────────────────────────────────────┘
```

#### Scenario B: AI Interpretation Failure

```
┌─────────────────────────────────────────────┐
│       Couldn't understand your query        │
│                                             │
│  🤔 Try being more specific:                │
│                                             │
│  ✅ "barber near me"                        │ ← Examples
│  ✅ "car rental under $500"                 │
│  ✅ "pizza delivery Port of Spain"          │
│                                             │
│  ❌ "thing near place"                      │
│  ❌ "stuff"                                 │
│                                             │
│  [Try Keyword Search Instead]               │ ← Button → fallback
│                                             │
└─────────────────────────────────────────────┘
```

#### Scenario C: Network Error

```
┌─────────────────────────────────────────────┐
│          Connection problem                 │
│                                             │
│  ⚠️ Unable to reach server.                 │
│     Check your internet connection.         │
│                                             │
│  [Retry]          [Search Offline]          │ ← Buttons
│                                             │
└─────────────────────────────────────────────┘
```

**Interactions**:
- Broaden Radius Button:
  - Re-queries with 2x radius
- Show All Button:
  - Removes strict filters, keeps category
- Suggested Searches:
  - Tappable, executes new search
- Keyword Search Fallback:
  - Switches to non-AI search (existing SearchBloc fuzzy matching)

---

### 5. SavedSearchesScreen

**Purpose**: Manage user's saved searches.

**Layout**:
```
┌─────────────────────────────────────────────┐
│ ← [Back]       Saved Searches               │ ← AppBar
├─────────────────────────────────────────────┤
│                                             │
│  ┌────────────────────────────────────┐    │
│  │ ⭐ Barber near Gulf City           │    │ ← Saved Search Card
│  │    🔔 Notifications ON              │    │
│  │    Last run: 2 days ago             │    │
│  │    [Run Now]  [Edit]  [Delete]      │    │
│  └────────────────────────────────────┘    │
│                                             │
│  ┌────────────────────────────────────┐    │
│  │ ⭐ Party supplies under $500       │    │
│  │    🔕 Notifications OFF             │    │
│  │    Last run: 1 week ago             │    │
│  │    [Run Now]  [Edit]  [Delete]      │    │
│  └────────────────────────────────────┘    │
│                                             │
│  [+ Create New Saved Search]                │ ← Opens SearchEntryScreen
│                                             │
└─────────────────────────────────────────────┘
```

**Components**:
- Each SavedSearch Card shows:
  - Query text (friendly name)
  - Notification status (🔔 ON / 🔕 OFF)
  - Last run timestamp
  - Action buttons: Run Now, Edit, Delete
- Empty state if no saved searches:
  - "Save searches to get notified of new matches!"

**Interactions**:
- Run Now: Executes search, navigates to SearchResultsScreen
- Edit: Opens dialog to rename or toggle notifications
- Delete: Confirms, then deletes from Firestore
- Create New: Opens SearchEntryScreen

---

### 6. FiltersScreen (Advanced, Optional)

**Purpose**: Manual filter adjustment (for users who prefer not to use AI).

**Layout**:
```
┌─────────────────────────────────────────────┐
│ ← [Back]         Filters          [Reset]   │
├─────────────────────────────────────────────┤
│                                             │
│  ──── Category ────                         │
│  [ Dropdown: All Categories ▼ ]            │
│                                             │
│  ──── Location ────                         │
│  [ Text: "Gulf City" ]   [📍 Use GPS]      │
│  Radius: ○─────●────────○ 5 km              │
│                                             │
│  ──── Price Range ────                      │
│  Min: [ $0 ]   Max: [ $1000 ]               │
│                                             │
│  ──── Quality Filters ────                  │
│  ☑️ Only Vouched sellers                    │
│  ☑️ Top rated (4.5+ stars)                  │
│  ☑️ Verified listings                       │
│                                             │
│  ──── Availability ────                     │
│  ☑️ Open now                                │
│  ☑️ Delivery available                      │
│  ☑️ Bookable online                         │
│                                             │
│  [Apply Filters]                            │
│                                             │
└─────────────────────────────────────────────┘
```

**Interactions**:
- Apply Filters:
  - Closes screen
  - Returns filters to search
  - Re-queries Firestore (bypasses AI)
- Reset:
  - Clears all filters

---

## Component Library

### 1. SearchFilterChip

**Design**:
```
┌────────────────────┐
│ 📍 Gulf City  ⓧ   │  ← Icon + Text + Close button
└────────────────────┘
```

**Variants**:
- **Removable**: Shows ⓧ button
- **Editable**: Tappable, opens edit dialog
- **Static**: Display-only (e.g., "Top rated")

**Props**:
- `icon: IconData`
- `label: String`
- `onRemove: Function?`
- `onTap: Function?`
- `color: Color` (default: light gray, accent for active)

---

### 2. SearchResultCard

**Design**:
```
┌──────────────────────────────────────┐
│ [Image 80x80]   Title                │
│                  ⭐ 4.8 · 23 reviews  │
│                  📍 2.1 km away       │
│                  💰 $50 - $100        │
│                                      │
│ 🔵 Vouched · Near you · Top rated    │ ← Explanation row
└──────────────────────────────────────┘
```

**Props**:
- `listing: ListingModel OR deal: DealAdModel`
- `explanationChips: List<String>` (e.g., ["Vouched", "Near you"])
- `onTap: Function`

**Behavior**:
- Tapping card: Navigates to details
- Long-press: Shows context menu (Save, Share, Report)

---

### 3. SuggestionChip

**Design**:
```
┌───────────────────────────────────────┐
│ 💡 Try: "barber near Gulf City"      │ ← Tappable pill
└───────────────────────────────────────┘
```

**Props**:
- `suggestion: String`
- `onTap: Function`

**Behavior**:
- Tapping fills search field

---

### 4. ExplanationChip

**Design**:
```
┌────────────┐
│ 🔵 Vouched │  ← Small badge-style chip
└────────────┘
```

**Variants**:
- `Vouched` (blue badge icon)
- `Near you` (location pin icon)
- `Top rated` (star icon)
- `Matches 'X'` (magnifying glass icon)
- `Open now` (clock icon)
- `Delivery` (truck icon)

**Props**:
- `type: ExplanationChipType`
- `label: String`

---

## Interaction Patterns

### 1. Search Flow Interaction

**States**:
```
Idle → Typing → Submitting → Loading → Success | Error | Empty
```

**Loading States**:
- **Interpreting**: "Understanding your search..." (spinner)
- **Fetching**: "Loading results..." (skeleton cards OR spinner)

**Transitions**:
- Smooth fade-in for results
- Skeleton loading for cards (optional)

---

### 2. Filter Chip Editing

**Example: Location Chip**

```
User taps "📍 Gulf City" chip
  → BottomSheet opens:
      [ Search location... ]  ← Text input with autocomplete
      [ ○ Use current location ]
      [ Radius: ○──●───○ 10 km ]
      [Apply]  [Cancel]
  → User adjusts, taps Apply
  → Chip updates: "📍 Gulf City (10km)"
  → Results refresh
```

**Example: Price Chip**

```
User taps "💰 Under $500" chip
  → BottomSheet opens:
      Min: [ $0     ]
      Max: [ $__500_ ]  ← Editable text field
      [ Slider: ○──────●───○ ]
      [Apply]  [Cancel]
  → User adjusts to $300
  → Chip updates: "💰 Under $300"
  → Results refresh
```

---

### 3. Refinement Input Behavior

**Context Awareness**:
- Refinement text is appended to original query context
- Example:
  - Original: "barber near Gulf City"
  - Refinement: "only delivery"
  - Sent to AI: "barber near Gulf City, only delivery"

**Debouncing**:
- Wait 500ms after typing stops before submitting (optional, can be Enter-only)

---

## Empty States & Error Handling

### Empty State Hierarchy

1. **Zero Results (Specific Query)**:
   - Show broadening suggestions
   - Show alternate searches
   - Show nearby popular items in same category

2. **Zero Results (Too Broad)**:
   - "Try being more specific"
   - Show category list
   - Show featured/popular listings as fallback

3. **AI Interpretation Failure**:
   - "Couldn't understand your query"
   - Show examples of good queries
   - Offer keyword search fallback

4. **Network Error**:
   - "Connection problem"
   - Retry button
   - Offline mode (search recent/cached)

5. **Rate Limit Exceeded**:
   - "You've reached your search limit"
   - Show current tier limit
   - "Upgrade to Professional for more searches"
   - Offer keyword search fallback (unlimited)

---

## Accessibility

### Screen Reader Support

- All buttons have semantic labels
- Filter chips announce: "Filter: Location Gulf City, removable, tap to edit"
- Result cards announce: "Listing: Classic Cuts Barber, rated 4.8 stars, 2.1 kilometers away, Vouched seller, Near you"

### Keyboard Navigation

- Tab order: Search field → Filters → Results
- Enter key: Submit search
- Escape key: Clear search field
- Arrow keys: Navigate result cards

### Color Contrast

- All text: minimum 4.5:1 contrast ratio
- Interactive elements: minimum 3:1
- Icons paired with text labels

### Font Scaling

- Support Dynamic Type / system font scaling
- Test at 200% zoom

---

## Localization

### Supported Languages

- **English** (primary)
- **Spanish** (Phase 2)
- **French** (Phase 2)

### Translatable Strings

All UI text must be externalized:

```dart
// Example keys
"search.entry.placeholder": "Search listings, deals...",
"search.results.empty.title": "No results found",
"search.results.empty.broaden": "Try broadening your search",
"search.explanation.ai_understood": "AI understood your query",
"search.filter.location": "Location",
"search.filter.category": "Category",
"search.chip.vouched": "Vouched",
"search.chip.near_you": "Near you",
```

### Trinidad/Tobago Localization

- Place names: Gulf City, Trincity, Port of Spain, San Fernando, Tobago
- Currency: TTD (Trinidad and Tobago Dollar) display
- Distance: Kilometers (not miles)
- Date/time: 24-hour format preferred, but support 12-hour

---

## Design Tokens

### Colors

```dart
// Primary
colorPrimary: Color(0xFF1E88E5), // CaribTap blue (from existing config)

// Semantic
colorSearchActive: Color(0xFF43A047), // Green for active search
colorFilterChip: Color(0xFFE0E0E0), // Light gray for chips
colorFilterChipActive: Color(0xFF1E88E5), // Blue for active filter
colorExplanationChip: Color(0xFFF5F5F5), // Very light gray

// Status
colorError: Color(0xFFE53935),
colorWarning: Color(0xFFFB8C00),
colorSuccess: Color(0xFF43A047),
```

### Typography

```dart
// Search Field
searchFieldTextStyle: TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.normal,
  color: Colors.black87,
)

// Filter Chip
filterChipTextStyle: TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: Colors.black87,
)

// Result Title
resultTitleTextStyle: TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: Colors.black87,
)

// Explanation Chip
explanationChipTextStyle: TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.normal,
  color: Colors.black54,
)
```

### Spacing

```dart
spacingXS: 4.0,
spacingS: 8.0,
spacingM: 16.0,
spacingL: 24.0,
spacingXL: 32.0,
```

---

## Animation & Transitions

### Page Transitions
- **Search Entry → Results**: Slide up (300ms, easeOut)
- **Results → Details**: Fade + scale (250ms, easeInOut)

### Filter Chip Add/Remove
- Add: Fade in + slide in from left (200ms)
- Remove: Fade out + scale down (150ms)

### Loading States
- Spinner: Rotate continuously
- Skeleton cards: Shimmer effect (1000ms loop)

---

## Platform-Specific Considerations

### Android
- Use Material Design 3 components
- Bottom navigation bar
- FAB for "New Search" (optional)

### iOS
- Use Cupertino widgets where appropriate
- Tab bar navigation
- Pull-to-refresh on results

### Web (Future)
- Responsive layout (mobile-first, then tablet, desktop)
- Keyboard shortcuts (Ctrl+F for search)
- URL parameters for deep linkable searches: `/search?q=barber+gulf+city`

---

## Next Steps

1. **Mockup Review**: Create high-fidelity mockups in Figma based on this spec
2. **Usability Testing**: Test with 5-10 users (paper prototypes or clickable prototypes)
3. **Iterate**: Refine based on feedback
4. **Handoff to Dev**: Use this spec + mockups for implementation

---

**Document Owner**: CaribTap UX Team  
**Reviewers**: Product, Engineering, Design  
**Next Review**: After mockup completion
