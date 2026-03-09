import 'package:caribtap/listings/model/tutorial_article.dart';

class TutorialContentService {
  static List<TutorialArticle> getArticles({String languageCode = 'en'}) {
    final articles = [
      _article(
        id: 'getting_started_what_is_caribtap',
        title: 'What is CaribTap',
        category: 'Getting Started',
        summary:
            'Understand what CaribTap is and how people use it to buy, sell, and discover services.',
        whatThisDoes:
            'CaribTap connects people with local businesses and creators through listings, rentals, bookings, mini stores, and direct conversations.',
        whoShouldUseIt:
            'New users, shoppers, and business owners setting up for the first time.',
        steps: [
          'Create your account and complete your profile with your business name and contact details.',
          'Use Home, Categories, and Search to discover listings near you.',
          'Open listing details to view photos, pricing, delivery info, and seller verification.',
          'Use favourites to save useful listings like phone repair services or birthday cakes for later.',
        ],
        tips: [
          'Turn on notifications so you do not miss replies or order updates.',
          'Use clear profile information to build trust faster.',
        ],
        commonIssues: [
          'If feed results look limited, check your location permissions and filters.',
          'If you cannot message a seller, confirm your account email and internet connection.',
        ],
      ),
      _article(
        id: 'getting_started_search_businesses',
        title: 'How to search for businesses',
        category: 'Getting Started',
        summary:
            'Use filters and search terms to find the right business quickly.',
        whatThisDoes:
            'Search helps you find businesses, products, and services by keyword, category, and location.',
        whoShouldUseIt: 'Customers looking for specific products or services.',
        steps: [
          'Open Search from the main menu.',
          'Enter what you need, such as car rental, party supplies, or doubles.',
          'Apply filters like category, distance, and price range.',
          'Open a listing and compare details before contacting the seller.',
        ],
        tips: [
          'Use specific terms like "gift cards" or "colouring books" for better results.',
          'Try nearby town names if you are not seeing enough options.',
        ],
        commonIssues: [
          'Broad terms can return too many results, so add product type or location.',
          'Empty results usually mean filters are too strict.',
        ],
      ),
      _article(
        id: 'getting_started_contact_seller',
        title: 'How to contact a seller',
        category: 'Getting Started',
        summary: 'Send clear messages to sellers and get faster replies.',
        whatThisDoes:
            'Conversations let you ask questions, confirm availability, and agree on next steps safely in-app.',
        whoShouldUseIt: 'Customers preparing to buy, book, or rent.',
        steps: [
          'Open the listing and tap the contact or chat action.',
          'Send a short message with the item and quantity you need.',
          'Ask about delivery, pickup, lead time, and accepted payment methods.',
          'Save important agreement details in chat before placing an order.',
        ],
        tips: [
          'Include dates for rentals or bookings to avoid back-and-forth.',
          'Be specific: "Do you have 2 birthday cake toppers for Saturday?"',
        ],
        commonIssues: [
          'Slow replies can happen outside business hours.',
          'If chat does not open, update the app and check connectivity.',
        ],
      ),
      _article(
        id: 'getting_started_favourites_deals',
        title: 'How to save favourites and deals',
        category: 'Getting Started',
        summary: 'Keep track of listings and promotions you want to revisit.',
        whatThisDoes:
            'Favourites and saved deals give you a quick list of items and businesses you care about.',
        whoShouldUseIt: 'Users comparing options before buying.',
        steps: [
          'Tap the heart icon on listings you want to save.',
          'Open your saved area from the app menu.',
          'Review prices and compare options side by side.',
          'Unsave listings you no longer need to keep your list clean.',
        ],
        tips: [
          'Save seasonal items early, such as party supplies for events.',
          'Use saved deals to monitor price drops before checkout.',
        ],
        commonIssues: [
          'If favourites disappear, verify you are logged into the correct account.',
          'Some old deals expire and are removed automatically.',
        ],
      ),
      _article(
        id: 'getting_started_keywords',
        title: 'How to use keywords when searching',
        category: 'Getting Started',
        summary: 'Improve search quality with better keywords and phrasing.',
        whatThisDoes:
            'Keywords help Search match you with listings that describe exactly what you need.',
        whoShouldUseIt:
            'Anyone trying to find precise products or services faster.',
        steps: [
          'Start with the exact item or service name.',
          'Add useful qualifiers like size, location, or style.',
          'Try alternative terms if needed, such as "phone repair" and "screen replacement".',
          'Use short focused phrases instead of long sentences.',
        ],
        tips: [
          'Use plural and singular forms when exploring results.',
          'Include local words customers use in your area.',
        ],
        commonIssues: [
          'Misspelled terms can reduce match quality.',
          'Very generic words can hide niche results.',
        ],
      ),
      _article(
        id: 'buying_browse_listings',
        title: 'How to browse listings',
        category: 'Buying & Discovering',
        summary: 'Navigate feeds and categories to discover useful options.',
        whatThisDoes:
            'Browsing helps you discover new businesses and compare available offers quickly.',
        whoShouldUseIt: 'Shoppers exploring options before making a decision.',
        steps: [
          'Use the Home feed for featured and recent listings.',
          'Switch to Categories for focused discovery.',
          'Open listing cards to inspect photos, descriptions, and seller details.',
          'Save or contact sellers directly from listing details.',
        ],
        tips: [
          'Scroll by category when you are not sure what to search for.',
          'Check posted dates for fresher options.',
        ],
        commonIssues: [
          'If images load slowly, try switching network or reducing background apps.',
          'Older listings may have outdated stock details.',
        ],
      ),
      _article(
        id: 'buying_deals_mini_stores',
        title: 'How to find deals and mini stores',
        category: 'Buying & Discovering',
        summary: 'Find promotions and browse seller mini stores in one place.',
        whatThisDoes:
            'Deals highlight limited-time offers, while mini stores organize a seller\'s catalog for easier shopping.',
        whoShouldUseIt: 'Users looking for value offers and repeat purchases.',
        steps: [
          'Open Deals & Promotions from the app.',
          'Filter by category or location for relevant offers.',
          'Visit a seller mini store to see full product range, such as gift cards and colouring books.',
          'Message the seller to confirm current availability.',
        ],
        tips: [
          'Save strong deals early because stock can run out quickly.',
          'Check mini stores for bundles and add-on items.',
        ],
        commonIssues: [
          'Expired deals may still appear in old links.',
          'Some mini store items are pickup-only, so confirm delivery options.',
        ],
      ),
      _article(
        id: 'buying_rentals_work',
        title: 'How rentals work',
        category: 'Buying & Discovering',
        summary: 'Understand rental flow from request to return.',
        whatThisDoes:
            'CaribTap rentals allow customers to request temporary use of items and services with clear dates and terms.',
        whoShouldUseIt:
            'Customers renting items like vehicles, tools, or event equipment.',
        steps: [
          'Open a rental listing and review price, deposit, and policy details.',
          'Select dates and send your rental request.',
          'Wait for seller approval and confirmation instructions.',
          'Complete handover, use the item, then return based on agreed schedule.',
        ],
        tips: [
          'Double-check pickup and return times before confirming.',
          'For car rental, verify license requirements and fuel terms in advance.',
        ],
        commonIssues: [
          'Requests can be declined if dates conflict with availability.',
          'Late return fees may apply based on listing policy.',
        ],
      ),
      _article(
        id: 'buying_bookings_work',
        title: 'How bookings work',
        category: 'Buying & Discovering',
        summary:
            'Book service-based businesses with clear dates and expectations.',
        whatThisDoes:
            'Bookings help customers reserve time slots for services such as catering, events, or appointments.',
        whoShouldUseIt: 'Customers needing time-based services.',
        steps: [
          'Open a listing with booking enabled.',
          'Choose date and time based on available slots.',
          'Add service details and submit booking request.',
          'Wait for business confirmation and follow-up instructions.',
        ],
        tips: [
          'Include event size and location so sellers can quote accurately.',
          'Book early for weekend demand peaks.',
        ],
        commonIssues: [
          'Unavailable slots usually mean another customer confirmed first.',
          'Missing booking notes can delay approval.',
        ],
      ),
      _article(
        id: 'buying_verify_businesses',
        title: 'How to verify businesses',
        category: 'Buying & Discovering',
        summary: 'Use profile and listing signals to make safer decisions.',
        whatThisDoes:
            'Verification checks help you assess reliability before paying or sharing sensitive details.',
        whoShouldUseIt: 'All customers placing orders, bookings, or rentals.',
        steps: [
          'Review seller profile completeness and listing quality.',
          'Read listing details and check if terms are clear.',
          'Check previous activity indicators such as consistency and response quality.',
          'Use in-app messages to confirm specifics before payment.',
        ],
        tips: [
          'Ask for clear pickup and return terms for high-value rentals.',
          'Keep all key agreements in app chat.',
        ],
        commonIssues: [
          'Rushing into off-platform payments increases risk.',
          'If details are vague, request clarification before committing.',
        ],
      ),
      _article(
        id: 'selling_create_listing',
        title: 'How to create a listing',
        category: 'Selling on CaribTap',
        summary: 'Publish a listing that customers can discover and contact.',
        whatThisDoes:
            'Listing creation makes your products or services visible across CaribTap search and feeds.',
        whoShouldUseIt: 'Any seller offering products, rentals, or services.',
        steps: [
          'Tap Add Listing from the main app bar.',
          'Select the best category and add a clear title.',
          'Upload photos, set price, and write useful description details.',
          'Publish and monitor responses from interested customers.',
        ],
        tips: [
          'Use specific titles like "Phone repair - same day screen replacement".',
          'Set accurate stock or availability to avoid cancellations.',
        ],
        commonIssues: [
          'Missing required fields can block publishing.',
          'Low-quality photos reduce listing performance.',
        ],
      ),
      _article(
        id: 'selling_strong_listing',
        title: 'How to write a strong listing',
        category: 'Selling on CaribTap',
        summary: 'Structure your listing to answer buyer questions fast.',
        whatThisDoes:
            'A strong listing improves trust, conversion, and fewer repetitive questions from customers.',
        whoShouldUseIt: 'Sellers trying to improve views, taps, and orders.',
        steps: [
          'Start with a precise title and product type.',
          'Write a short intro and include condition, size, and variants.',
          'Add delivery, pickup, and payment instructions.',
          'Close with clear call to action and response time expectations.',
        ],
        tips: [
          'For birthday cakes, include lead time, serving size, and customization options.',
          'For doubles or prepared food, list operating hours and sold-out limits.',
        ],
        commonIssues: [
          'Overly short descriptions lead to repeated customer questions.',
          'Unclear pricing can reduce trust and conversions.',
        ],
      ),
      _article(
        id: 'selling_keywords',
        title: 'How keywords help customers find you',
        category: 'Selling on CaribTap',
        summary:
            'Use keywords strategically so your listing appears in relevant searches.',
        whatThisDoes:
            'Keyword-rich titles and descriptions improve search match quality for buyer intent.',
        whoShouldUseIt: 'Sellers who want more discoverability from search.',
        steps: [
          'Identify words buyers use for your product.',
          'Place primary keywords in title and first sentence.',
          'Add supporting keywords naturally in description.',
          'Update keywords when demand trends change.',
        ],
        tips: [
          'Use both broad and specific terms, for example "party supplies" and "baby shower balloons".',
          'Keep wording human-readable, not keyword spam.',
        ],
        commonIssues: [
          'Irrelevant keywords can attract the wrong audience.',
          'Repeating the same term excessively can hurt clarity.',
        ],
      ),
      _article(
        id: 'selling_good_photos',
        title: 'How to upload good photos',
        category: 'Selling on CaribTap',
        summary:
            'Capture and upload photos that build trust and improve conversions.',
        whatThisDoes:
            'High-quality photos help customers understand your offer quickly and increase confidence before messaging.',
        whoShouldUseIt: 'All sellers posting products, services, or rentals.',
        steps: [
          'Use bright natural light and clean backgrounds.',
          'Add multiple angles and close-up detail shots.',
          'Crop distractions and keep image orientation consistent.',
          'Upload and review in listing preview before publishing.',
        ],
        tips: [
          'Use AI photo enhancement to improve clarity without over-editing.',
          'Show scale by including context for size-sensitive items.',
        ],
        commonIssues: [
          'Blurry photos reduce trust and click-through.',
          'Heavy filters can make actual products look different in person.',
        ],
      ),
      _article(
        id: 'selling_manage_listings',
        title: 'How to manage your listings',
        category: 'Selling on CaribTap',
        summary: 'Keep listings updated to stay discoverable and accurate.',
        whatThisDoes:
            'Listing management helps you edit pricing, stock, and status as your business changes.',
        whoShouldUseIt: 'Sellers with active or seasonal inventory.',
        steps: [
          'Open My Listings from the drawer menu.',
          'Edit title, photos, price, and details as needed.',
          'Pause or reactivate listings based on stock.',
          'Refresh outdated content to keep your listing relevant.',
        ],
        tips: [
          'Update pricing quickly when supplier costs change.',
          'Retire duplicates to avoid confusing customers.',
        ],
        commonIssues: [
          'Leaving sold-out listings active can trigger customer complaints.',
          'Inconsistent listing info across branches can reduce trust.',
        ],
      ),
      _article(
        id: 'rentals_how_listings_work',
        title: 'How rental listings work',
        category: 'Rentals & Bookings',
        summary: 'Set up rental listings with clear terms and rates.',
        whatThisDoes:
            'Rental listings define pricing, deposit, availability, and conditions so customers know exactly what to expect.',
        whoShouldUseIt:
            'Sellers offering short-term use of products or vehicles.',
        steps: [
          'Create or edit a listing and enable rental options.',
          'Set rental period, rates, and any deposit requirements.',
          'Define pickup, return, and late fee rules.',
          'Publish and monitor rental requests in your dashboard.',
        ],
        tips: [
          'Use clear damage and return terms to prevent disputes.',
          'State what is included, like mileage limits for car rental.',
        ],
        commonIssues: [
          'Missing policy details can cause customer confusion.',
          'Unclear deposit rules may delay confirmations.',
        ],
      ),
      _article(
        id: 'rentals_customer_requests',
        title: 'How customers request rentals',
        category: 'Rentals & Bookings',
        summary: 'See how customers submit dates and request approvals.',
        whatThisDoes:
            'Request flow allows customers to choose dates and send rental inquiries directly through the app.',
        whoShouldUseIt: 'Rental providers handling incoming customer requests.',
        steps: [
          'Customers select dates and submit rental details.',
          'You receive request details including duration and notes.',
          'Review availability and approve or decline.',
          'Send confirmation instructions through chat.',
        ],
        tips: [
          'Respond quickly to protect conversion rates.',
          'Request missing details before approving high-value rentals.',
        ],
        commonIssues: [
          'Incomplete customer notes can slow decision-making.',
          'Overlapping requests require strict availability control.',
        ],
      ),
      _article(
        id: 'rentals_approve_requests',
        title: 'How to approve rental requests',
        category: 'Rentals & Bookings',
        summary: 'Approve requests with clear confirmation and conditions.',
        whatThisDoes:
            'Approval flow lets sellers confirm the request and lock in terms before handover.',
        whoShouldUseIt: 'Rental providers and team members managing approvals.',
        steps: [
          'Open Rental Requests from your rentals area.',
          'Verify date availability and customer notes.',
          'Approve, reject, or request more details.',
          'Share pickup instructions and required documents.',
        ],
        tips: [
          'Confirm customer identity requirements before handover.',
          'Use chat to document final agreement details.',
        ],
        commonIssues: [
          'Approving without verifying dates can cause double bookings.',
          'Missing handover details can lead to no-shows.',
        ],
      ),
      _article(
        id: 'rentals_handover_returns',
        title: 'How handover and returns work',
        category: 'Rentals & Bookings',
        summary: 'Manage pickup and return smoothly with clear records.',
        whatThisDoes:
            'Handover and return processes reduce disputes by setting expectations before and after rental use.',
        whoShouldUseIt: 'Rental businesses handling physical item exchange.',
        steps: [
          'Confirm handover time and location with customer.',
          'Inspect item condition and document key notes.',
          'At return, verify condition and completeness.',
          'Close rental and update status in your records.',
        ],
        tips: [
          'Take reference photos at pickup and return for high-value items.',
          'Share return reminders ahead of due time.',
        ],
        commonIssues: [
          'Late returns can affect future reservations.',
          'Unrecorded condition notes make disputes harder to resolve.',
        ],
      ),
      _article(
        id: 'rentals_manage_availability',
        title: 'Managing availability',
        category: 'Rentals & Bookings',
        summary:
            'Control availability so customers can only request open dates.',
        whatThisDoes:
            'Availability management keeps your rental schedule accurate and reduces conflicts.',
        whoShouldUseIt: 'Sellers with recurring rental demand.',
        steps: [
          'Open your rental listing settings.',
          'Block unavailable dates and update active windows.',
          'Review upcoming requests daily.',
          'Adjust availability immediately after approvals or cancellations.',
        ],
        tips: [
          'Keep a daily routine for checking schedule conflicts.',
          'Use clear cutoff times for same-day bookings.',
        ],
        commonIssues: [
          'Delayed updates can cause overlapping reservations.',
          'Not blocking maintenance days can trigger avoidable cancellations.',
        ],
      ),
      _article(
        id: 'business_ai_photo_enhancement',
        title: 'AI photo enhancement',
        category: 'Business Tools',
        summary:
            'Improve listing images quickly with built-in AI photo enhancement tools.',
        whatThisDoes:
            'AI photo enhancement improves lighting, clarity, and overall image quality to help listings stand out.',
        whoShouldUseIt:
            'Sellers who want better visual performance with minimal editing effort.',
        steps: [
          'Open your listing media section and choose a photo.',
          'Launch AI photo enhancement and preview generated variants.',
          'Select the best result and compare before/after.',
          'Save the enhanced image to your listing.',
        ],
        tips: [
          'Use enhancement on original high-resolution photos for best results.',
          'Keep results natural so the product still matches reality.',
        ],
        commonIssues: [
          'Very dark originals may still require retaking the photo.',
          'Over-enhanced images can look artificial and reduce trust.',
        ],
      ),
      _article(
        id: 'business_quotes_invoices',
        title: 'Quotes and invoices',
        category: 'Business Tools',
        summary: 'Create professional quotes and invoices for customer jobs.',
        whatThisDoes:
            'Quotes and invoices help businesses present formal pricing, track approvals, and support payment flow.',
        whoShouldUseIt:
            'Service providers, custom-order sellers, and teams managing client jobs.',
        steps: [
          'Open Quotes & Invoices from the menu.',
          'Create a quote with items, pricing, and validity date.',
          'Convert approved quote into an invoice when needed.',
          'Share with customer and track status updates.',
        ],
        tips: [
          'Add clear line items to reduce disputes.',
          'Include payment terms and due date on every invoice.',
        ],
        commonIssues: [
          'Missing customer details can delay acceptance.',
          'Unclear tax or fee breakdown can cause confusion.',
        ],
      ),
      _article(
        id: 'business_multi_location_brands',
        title: 'Multi-location brands',
        category: 'Business Tools',
        summary: 'Manage multiple branches under one business identity.',
        whatThisDoes:
            'Multi-location brands let you organize listings and visibility across several branch locations.',
        whoShouldUseIt:
            'Businesses with more than one branch or service point.',
        steps: [
          'Open My Brands/Branches from the drawer.',
          'Create or update each branch profile.',
          'Assign listings to the correct location.',
          'Review branch-specific info such as opening hours and contacts.',
        ],
        tips: [
          'Keep branch naming consistent for easier customer recognition.',
          'Set accurate local delivery or pickup rules per location.',
        ],
        commonIssues: [
          'Wrong branch assignment can route customers to the wrong place.',
          'Incomplete branch data lowers trust.',
        ],
      ),
      _article(
        id: 'business_assign_team_listings',
        title: 'Assigning listings to team members',
        category: 'Business Tools',
        summary: 'Use collaboration tools to delegate listing tasks to staff.',
        whatThisDoes:
            'Assigned listings allow teams to share workload while keeping ownership and accountability clear.',
        whoShouldUseIt:
            'Growing businesses with staff handling updates and customer messages.',
        steps: [
          'Open collaboration or assigned listings tools.',
          'Select listing and assign responsible teammate.',
          'Set expectations for updates, replies, and turnaround time.',
          'Review activity logs for accountability.',
        ],
        tips: [
          'Assign by category expertise for better quality control.',
          'Use a backup assignee for urgent periods.',
        ],
        commonIssues: [
          'Unclear ownership can cause duplicate replies.',
          'No review routine can leave listings outdated.',
        ],
      ),
      _article(
        id: 'business_table_mode',
        title: 'Using table mode',
        category: 'Business Tools',
        summary: 'Run table-side ordering workflows with table mode tools.',
        whatThisDoes:
            'Table mode supports quick in-person ordering and table session management for food businesses.',
        whoShouldUseIt:
            'Restaurants and vendors serving customers at tables or stalls.',
        steps: [
          'Open table mode tools from your business features.',
          'Set up tables and staff access.',
          'Start sessions and capture orders per table.',
          'Close sessions after payment confirmation.',
        ],
        tips: [
          'Use QR flow where possible to reduce manual entry.',
          'Train staff on open session checks before shift change.',
        ],
        commonIssues: [
          'Unclosed sessions can cause order reconciliation gaps.',
          'Incorrect table mapping leads to delayed service.',
        ],
      ),
      _article(
        id: 'business_catalog_store_management',
        title: 'Catalog and store management',
        category: 'Business Tools',
        summary: 'Organize mini store products and keep your catalog accurate.',
        whatThisDoes:
            'Catalog management helps sellers structure products for easier browsing and ordering.',
        whoShouldUseIt:
            'Sellers maintaining mini stores or larger product inventories.',
        steps: [
          'Open your store or catalog management screen.',
          'Group products into clear sections.',
          'Update pricing, stock, and descriptions regularly.',
          'Archive unavailable items to keep the catalog clean.',
        ],
        tips: [
          'Use clear product names and consistent photo style.',
          'Create seasonal collections for faster customer browsing.',
        ],
        commonIssues: [
          'Outdated stock values cause order cancellations.',
          'Large uncategorized catalogs reduce conversion.',
        ],
      ),
      _article(
        id: 'orders_proof_of_payment',
        title: 'Proof of payment',
        category: 'Orders & Payments',
        summary: 'Use proof of payment to confirm submitted customer payments.',
        whatThisDoes:
            'Proof of payment allows customers to upload payment evidence that sellers can review and verify.',
        whoShouldUseIt:
            'Sellers handling transfers and customers asked to submit payment evidence.',
        steps: [
          'Enable proof of payment where supported for your orders.',
          'Customer uploads image or PDF receipt in the order flow.',
          'Seller reviews and marks status as verified or rejected.',
          'Order proceeds after successful verification.',
        ],
        tips: [
          'Always check amount, date, and reference details before approving.',
          'Use reviewer notes when rejecting so customer can correct quickly.',
        ],
        commonIssues: [
          'Blurry receipts slow verification.',
          'Missing transfer references can require extra confirmation.',
        ],
      ),
      _article(
        id: 'orders_manage_orders',
        title: 'Managing orders',
        category: 'Orders & Payments',
        summary: 'Track order status from request to completion.',
        whatThisDoes:
            'Order management helps sellers process incoming requests and keep customers informed.',
        whoShouldUseIt: 'Businesses receiving regular order requests.',
        steps: [
          'Open order requests from the menu.',
          'Review customer details, items, and delivery notes.',
          'Accept, update status, and send timeline updates.',
          'Mark completed orders after fulfillment.',
        ],
        tips: [
          'Use status updates consistently to reduce support messages.',
          'Confirm substitutions before dispatching changed items.',
        ],
        commonIssues: [
          'Delayed status updates can create customer confusion.',
          'Skipping order notes can cause fulfillment mistakes.',
        ],
      ),
      _article(
        id: 'orders_payment_verification',
        title: 'Payment verification',
        category: 'Orders & Payments',
        summary: 'Verify incoming payments safely before releasing items.',
        whatThisDoes:
            'Payment verification adds a confirmation checkpoint to reduce fraud and mistaken fulfillment.',
        whoShouldUseIt:
            'Sellers accepting direct transfer or manual payment confirmation.',
        steps: [
          'Match payment details against order amount and customer name.',
          'Confirm reference IDs where available.',
          'Update order to verified once checks pass.',
          'Notify customer that processing is underway.',
        ],
        tips: [
          'Standardize your verification checklist for team consistency.',
          'Flag suspicious mismatches before dispatch.',
        ],
        commonIssues: [
          'Partial payments can be mistaken as complete.',
          'Delayed bank updates may require short waiting periods.',
        ],
      ),
      _article(
        id: 'orders_refunds_cancellations',
        title: 'Refunds and cancellations',
        category: 'Orders & Payments',
        summary:
            'Handle cancellations and refunds with clear customer communication.',
        whatThisDoes:
            'Refund and cancellation workflows protect customer trust and keep records clean.',
        whoShouldUseIt:
            'Sellers managing order exceptions and policy enforcement.',
        steps: [
          'Review cancellation reason and order status.',
          'Apply your published policy and confirm eligible amount.',
          'Process refund and update customer through chat.',
          'Mark final status to close the order properly.',
        ],
        tips: [
          'Publish policy terms in listing descriptions upfront.',
          'Keep timestamps and notes for every refund decision.',
        ],
        commonIssues: [
          'Unclear policy terms increase disputes.',
          'Missing order notes make audits difficult.',
        ],
      ),
      _article(
        id: 'advanced_vouches_taps',
        title: 'What are Vouches / Taps',
        category: 'Advanced Features',
        summary: 'Learn how trust and engagement signals work inside CaribTap.',
        whatThisDoes:
            'Vouches and taps are engagement signals that help people discover reliable listings and businesses.',
        whoShouldUseIt:
            'Customers evaluating businesses and sellers building social proof.',
        steps: [
          'View listing interaction indicators where available.',
          'Compare engagement with listing quality and recency.',
          'Use these signals as one input, not the only decision factor.',
          'Continue checking listing details and communication quality.',
        ],
        tips: [
          'Strong engagement plus clear listing info is a better trust signal.',
          'Use consistent service quality to earn better reputation over time.',
        ],
        commonIssues: [
          'New listings may have lower engagement despite being legitimate.',
          'Relying only on one metric can lead to poor decisions.',
        ],
      ),
      _article(
        id: 'advanced_freshness_ranking',
        title: 'Listing freshness and ranking',
        category: 'Advanced Features',
        summary: 'Understand how listing freshness affects visibility.',
        whatThisDoes:
            'Fresh listings with updated content tend to perform better in feed and search ranking systems.',
        whoShouldUseIt: 'Sellers who want stronger long-term discoverability.',
        steps: [
          'Review your active listings weekly.',
          'Update outdated details, photos, and pricing.',
          'Archive stale or unavailable listings.',
          'Track performance changes after updates.',
        ],
        tips: [
          'Regular updates are better than bulk edits once a year.',
          'Improve quality and freshness together for best results.',
        ],
        commonIssues: [
          'Old inaccurate details reduce customer trust.',
          'Frequent superficial edits without value may not help performance.',
        ],
      ),
      _article(
        id: 'advanced_barcode_scanning',
        title: 'Barcode scanning',
        category: 'Advanced Features',
        summary:
            'Use barcode tools where supported for faster product workflows.',
        whatThisDoes:
            'Barcode scanning speeds up item lookup and inventory-related actions.',
        whoShouldUseIt: 'Sellers with product catalogs that include barcodes.',
        steps: [
          'Open barcode scanning from the supported workflow.',
          'Point camera at a clear barcode under good lighting.',
          'Confirm matched item details before saving changes.',
          'Update quantity or listing data as required.',
        ],
        tips: [
          'Keep camera lens clean for better scan reliability.',
          'Use steady framing and avoid reflections on glossy labels.',
        ],
        commonIssues: [
          'Damaged barcodes may fail to scan.',
          'Low light can cause repeated scan errors.',
        ],
      ),
      _article(
        id: 'advanced_shipping_tracking',
        title: 'Shipping and tracking',
        category: 'Advanced Features',
        summary: 'Share shipping progress clearly with customers.',
        whatThisDoes:
            'Shipping and tracking workflows help customers know delivery progress and expected arrival windows.',
        whoShouldUseIt: 'Sellers shipping products to customers.',
        steps: [
          'Confirm order is packed and ready for dispatch.',
          'Add shipment details and courier references where available.',
          'Update status milestones as package moves.',
          'Mark delivered when completion is confirmed.',
        ],
        tips: [
          'Send proactive updates during delays to reduce complaints.',
          'Include delivery notes for hard-to-find addresses.',
        ],
        commonIssues: [
          'Missing tracking references create customer uncertainty.',
          'Status not updated after dispatch can trigger support load.',
        ],
      ),
      _article(
        id: 'advanced_notifications',
        title: 'Notifications',
        category: 'Advanced Features',
        summary: 'Manage notifications so you stay informed without overload.',
        whatThisDoes:
            'Notifications keep you updated on messages, orders, bookings, rentals, and account events.',
        whoShouldUseIt: 'All users who want timely updates on app activity.',
        steps: [
          'Enable push notifications in app and device settings.',
          'Review notification categories in your account preferences.',
          'Prioritize essential alerts such as orders and payment checks.',
          'Adjust settings as your usage evolves.',
        ],
        tips: [
          'Keep transactional alerts on even if you mute promotional notices.',
          'Use notification history to catch missed updates.',
        ],
        commonIssues: [
          'Disabled device permissions prevent app alerts from appearing.',
          'Battery optimization settings can delay notifications.',
        ],
      ),
      _article(
        id: 'account_subscription_plans',
        title: 'Subscription plans explained',
        category: 'Account & Subscriptions',
        summary:
            'Understand available subscription plans and what they unlock.',
        whatThisDoes:
            'Subscription plans define what business tools and limits your account can access.',
        whoShouldUseIt:
            'Sellers deciding when to move from free to paid tiers.',
        steps: [
          'Open subscription or upgrade screen from the app menu.',
          'Compare included features across plans.',
          'Check monthly versus yearly billing options.',
          'Choose the plan that matches your current business stage.',
        ],
        tips: [
          'Review your workflow needs before upgrading.',
          'Use trial periods or short cycles to validate value first.',
        ],
        commonIssues: [
          'Choosing a plan without checking feature limits can cause frustration.',
          'Confusing billing cycle with feature tier leads to wrong expectations.',
        ],
      ),
      _article(
        id: 'account_professional_vs_premium',
        title: 'Professional vs Premium features',
        category: 'Account & Subscriptions',
        summary: 'Compare Professional and Premium tools before upgrading.',
        whatThisDoes:
            'This comparison helps businesses choose the right level of tools for growth and operations.',
        whoShouldUseIt: 'Sellers evaluating advanced capabilities and ROI.',
        steps: [
          'Review Professional features like booking and core tools.',
          'Check Premium-only features such as expanded business workflows.',
          'Map features to your weekly operational needs.',
          'Upgrade when the feature set supports your next growth phase.',
        ],
        tips: [
          'If you rely on advanced workflows, Premium may save manual effort.',
          'Re-check plan details as new features roll out.',
        ],
        commonIssues: [
          'Upgrading too early can increase cost before value is realized.',
          'Staying on a lower tier may block needed workflows.',
        ],
      ),
      _article(
        id: 'account_manage_subscription',
        title: 'Managing your subscription',
        category: 'Account & Subscriptions',
        summary:
            'Update billing cycle or plan using built-in subscription controls.',
        whatThisDoes:
            'Subscription management lets you upgrade, downgrade, and monitor your active entitlement.',
        whoShouldUseIt:
            'Users with active paid plans or those planning plan changes.',
        steps: [
          'Open Manage Subscription from the account menu.',
          'Check your active plan and billing cycle.',
          'Apply plan changes based on your business needs.',
          'Confirm updates after purchase processing completes.',
        ],
        tips: [
          'Keep payment method details current to avoid interruptions.',
          'Review renewal date before making major plan changes.',
        ],
        commonIssues: [
          'Plan changes may appear delayed until store confirmation finishes.',
          'Expired payment methods can pause premium access.',
        ],
      ),
      _article(
        id: 'account_restore_purchases',
        title: 'Restoring purchases',
        category: 'Account & Subscriptions',
        summary:
            'Restore previous purchases after reinstalling or changing devices.',
        whatThisDoes:
            'Restore purchases re-syncs subscription entitlements with your app account when needed.',
        whoShouldUseIt:
            'Users who lost access after reinstall, device change, or sign-in issue.',
        steps: [
          'Sign in with the same account used for purchase.',
          'Open subscription screen and trigger restore purchases.',
          'Wait for store verification and entitlement refresh.',
          'Reopen the app if access does not update immediately.',
        ],
        tips: [
          'Use the same app store account that made the original purchase.',
          'Check internet connection before restoring.',
        ],
        commonIssues: [
          'Using a different store account prevents restore detection.',
          'Delayed store responses can temporarily postpone restoration.',
        ],
      ),
      _article(
        id: 'account_settings',
        title: 'Account settings',
        category: 'Account & Subscriptions',
        summary:
            'Manage personal account preferences and core profile options.',
        whatThisDoes:
            'Account settings control profile information, preferences, and communication options.',
        whoShouldUseIt:
            'All users maintaining profile accuracy and app preferences.',
        steps: [
          'Open Profile and account settings from the drawer.',
          'Update contact details, language, and relevant preferences.',
          'Review notification and privacy options.',
          'Save changes and confirm they reflect across your account.',
        ],
        tips: [
          'Keep phone and email current for support and verification.',
          'Review settings after major app updates.',
        ],
        commonIssues: [
          'Old contact details can delay important account notices.',
          'Unsaved changes are lost if you exit too quickly.',
        ],
      ),
    ];

    final overrides = _localizedTitleSummary(languageCode);
    final isSpanish = languageCode == 'es';

    if (overrides.isEmpty && !isSpanish) {
      return articles;
    }

    return articles.map((article) {
      final override = overrides[article.id];
      final spanishFallback =
          isSpanish ? _spanishBodyFallback(article, override) : null;

      if (override == null && spanishFallback == null) {
        return article;
      }

      return article.copyWith(
        title: override?.title ?? article.title,
        summary: override?.summary ?? article.summary,
        whatThisDoes: override?.whatThisDoes ??
            spanishFallback?.whatThisDoes ??
            article.whatThisDoes,
        whoShouldUseIt: override?.whoShouldUseIt ??
            spanishFallback?.whoShouldUseIt ??
            article.whoShouldUseIt,
        steps: override?.steps ?? spanishFallback?.steps ?? article.steps,
        tips: override?.tips ?? spanishFallback?.tips ?? article.tips,
        commonIssues: override?.commonIssues ??
            spanishFallback?.commonIssues ??
            article.commonIssues,
      );
    }).toList();
  }

  static _LocalizedArticleOverride _spanishBodyFallback(
    TutorialArticle article,
    _LocalizedArticleOverride? override,
  ) {
    final localizedTitle = override?.title ?? article.title;

    return _LocalizedArticleOverride(
      title: localizedTitle,
      summary: override?.summary ?? article.summary,
      whatThisDoes:
          'Esta guia explica como usar "$localizedTitle" dentro de CaribTap para lograr mejores resultados.',
      whoShouldUseIt:
          'Es ideal para usuarios y negocios que quieren aplicar "$localizedTitle" correctamente.',
      steps: [
        'Abre la seccion relacionada con "$localizedTitle" en la app.',
        'Revisa los detalles y configura la opcion segun tu caso.',
        'Confirma los cambios y verifica el resultado final.',
      ],
      tips: [
        'Mantiene la informacion clara y actualizada para evitar errores.',
        'Si tienes dudas, usa el chat para confirmar detalles antes de continuar.',
      ],
      commonIssues: [
        'Datos incompletos o desactualizados pueden afectar el resultado.',
        'Si no ves cambios, revisa tu conexion y actualiza la app.',
      ],
    );
  }

  static TutorialArticle _article({
    required String id,
    required String title,
    required String category,
    required String summary,
    required String whatThisDoes,
    required String whoShouldUseIt,
    required List<String> steps,
    required List<String> tips,
    required List<String> commonIssues,
  }) {
    return TutorialArticle(
      id: id,
      title: title,
      category: category,
      summary: summary,
      whatThisDoes: whatThisDoes,
      whoShouldUseIt: whoShouldUseIt,
      steps: steps,
      tips: tips,
      commonIssues: commonIssues,
    );
  }

  static Map<String, _LocalizedArticleOverride> _localizedTitleSummary(
      String languageCode) {
    switch (languageCode) {
      case 'es':
        return {
          'getting_started_what_is_caribtap': const _LocalizedArticleOverride(
            title: 'Que es CaribTap',
            summary:
                'Entiende que es CaribTap y como las personas lo usan para comprar, vender y descubrir servicios.',
          ),
          'getting_started_search_businesses': const _LocalizedArticleOverride(
            title: 'Como buscar negocios',
            summary:
                'Usa filtros y terminos de busqueda para encontrar el negocio correcto rapidamente.',
          ),
          'getting_started_contact_seller': const _LocalizedArticleOverride(
            title: 'Como contactar a un vendedor',
            summary:
                'Envia mensajes claros a los vendedores y obten respuestas mas rapidas.',
          ),
          'getting_started_favourites_deals': const _LocalizedArticleOverride(
            title: 'Como guardar favoritos y ofertas',
            summary:
                'Lleva control de listados y promociones que quieres revisar luego.',
          ),
          'getting_started_keywords': const _LocalizedArticleOverride(
            title: 'Como usar palabras clave al buscar',
            summary:
                'Mejora la calidad de busqueda con mejores palabras clave y frases.',
          ),
          'buying_browse_listings': const _LocalizedArticleOverride(
            title: 'Como explorar listados',
            summary:
                'Navega feeds y categorias para descubrir opciones utiles.',
          ),
          'buying_deals_mini_stores': const _LocalizedArticleOverride(
            title: 'Como encontrar ofertas y mini tiendas',
            summary:
                'Encuentra promociones y explora mini tiendas de vendedores en un solo lugar.',
          ),
          'buying_rentals_work': const _LocalizedArticleOverride(
            title: 'Como funcionan los alquileres',
            summary:
                'Entiende el flujo de alquiler desde la solicitud hasta la devolucion.',
          ),
          'buying_bookings_work': const _LocalizedArticleOverride(
            title: 'Como funcionan las reservas',
            summary:
                'Reserva negocios de servicios con fechas y expectativas claras.',
          ),
          'buying_verify_businesses': const _LocalizedArticleOverride(
            title: 'Como verificar negocios',
            summary:
                'Usa senales de perfil y listados para tomar decisiones mas seguras.',
          ),
          'selling_create_listing': const _LocalizedArticleOverride(
            title: 'Como crear un listado',
            summary:
                'Publica un listado que los clientes puedan descubrir y contactar.',
          ),
          'selling_strong_listing': const _LocalizedArticleOverride(
            title: 'Como escribir un listado fuerte',
            summary:
                'Estructura tu listado para responder preguntas de compradores mas rapido.',
          ),
          'selling_keywords': const _LocalizedArticleOverride(
            title: 'Como las palabras clave ayudan a que te encuentren',
            summary:
                'Usa palabras clave de forma estrategica para aparecer en busquedas relevantes.',
          ),
          'selling_good_photos': const _LocalizedArticleOverride(
            title: 'Como subir buenas fotos',
            summary:
                'Captura y sube fotos que generen confianza y mejoren conversiones.',
          ),
          'selling_manage_listings': const _LocalizedArticleOverride(
            title: 'Como gestionar tus listados',
            summary:
                'Mantiene tus listados actualizados para seguir siendo visible y preciso.',
          ),
          'rentals_how_listings_work': const _LocalizedArticleOverride(
            title: 'Como funcionan los listados de alquiler',
            summary:
                'Configura listados de alquiler con terminos y tarifas claras.',
          ),
          'rentals_customer_requests': const _LocalizedArticleOverride(
            title: 'Como los clientes solicitan alquileres',
            summary:
                'Mira como los clientes envian fechas y solicitudes para aprobacion.',
          ),
          'rentals_approve_requests': const _LocalizedArticleOverride(
            title: 'Como aprobar solicitudes de alquiler',
            summary:
                'Aprueba solicitudes con confirmacion y condiciones claras.',
          ),
          'rentals_handover_returns': const _LocalizedArticleOverride(
            title: 'Como funcionan entrega y devoluciones',
            summary:
                'Gestiona entrega y devolucion sin friccion con registros claros.',
          ),
          'rentals_manage_availability': const _LocalizedArticleOverride(
            title: 'Gestionar disponibilidad',
            summary:
                'Controla disponibilidad para que clientes solo soliciten fechas libres.',
          ),
          'business_ai_photo_enhancement': const _LocalizedArticleOverride(
            title: 'Mejora de fotos con IA',
            summary:
                'Mejora imagenes de listados rapidamente con herramientas integradas de IA.',
          ),
          'business_quotes_invoices': const _LocalizedArticleOverride(
            title: 'Cotizaciones y facturas',
            summary:
                'Crea cotizaciones y facturas profesionales para trabajos con clientes.',
          ),
          'business_multi_location_brands': const _LocalizedArticleOverride(
            title: 'Marcas con multiples ubicaciones',
            summary:
                'Gestiona multiples sucursales bajo una sola identidad de negocio.',
          ),
          'business_assign_team_listings': const _LocalizedArticleOverride(
            title: 'Asignar listados a miembros del equipo',
            summary:
                'Usa colaboracion para delegar tareas de listados al personal.',
          ),
          'business_table_mode': const _LocalizedArticleOverride(
            title: 'Usar modo mesa',
            summary:
                'Ejecuta flujos de pedidos en mesa con herramientas de modo mesa.',
          ),
          'business_catalog_store_management': const _LocalizedArticleOverride(
            title: 'Gestion de catalogo y tienda',
            summary:
                'Organiza productos de mini tienda y mantén tu catalogo preciso.',
          ),
          'orders_proof_of_payment': const _LocalizedArticleOverride(
            title: 'Comprobante de pago',
            summary:
                'Usa comprobante de pago para confirmar pagos enviados por clientes.',
          ),
          'orders_manage_orders': const _LocalizedArticleOverride(
            title: 'Gestion de pedidos',
            summary:
                'Rastrea el estado de pedidos desde solicitud hasta finalizacion.',
          ),
          'orders_payment_verification': const _LocalizedArticleOverride(
            title: 'Verificacion de pagos',
            summary:
                'Verifica pagos entrantes de forma segura antes de liberar articulos.',
          ),
          'orders_refunds_cancellations': const _LocalizedArticleOverride(
            title: 'Reembolsos y cancelaciones',
            summary:
                'Gestiona cancelaciones y reembolsos con comunicacion clara al cliente.',
          ),
          'advanced_vouches_taps': const _LocalizedArticleOverride(
            title: 'Que son Vouches / Taps',
            summary:
                'Aprende como funcionan las senales de confianza e interaccion en CaribTap.',
          ),
          'advanced_freshness_ranking': const _LocalizedArticleOverride(
            title: 'Frescura de listado y ranking',
            summary:
                'Entiende como la frescura del listado afecta la visibilidad.',
          ),
          'advanced_barcode_scanning': const _LocalizedArticleOverride(
            title: 'Escaneo de codigo de barras',
            summary:
                'Usa herramientas de codigo de barras para flujos de producto mas rapidos.',
          ),
          'advanced_shipping_tracking': const _LocalizedArticleOverride(
            title: 'Envio y seguimiento',
            summary: 'Comparte progreso de envio claramente con los clientes.',
          ),
          'advanced_notifications': const _LocalizedArticleOverride(
            title: 'Notificaciones',
            summary:
                'Gestiona notificaciones para mantenerte informado sin sobrecarga.',
          ),
          'account_subscription_plans': const _LocalizedArticleOverride(
            title: 'Planes de suscripcion explicados',
            summary:
                'Entiende planes de suscripcion disponibles y lo que desbloquean.',
          ),
          'account_professional_vs_premium': const _LocalizedArticleOverride(
            title: 'Funciones Professional vs Premium',
            summary:
                'Compara herramientas Professional y Premium antes de actualizar.',
          ),
          'account_manage_subscription': const _LocalizedArticleOverride(
            title: 'Gestionar tu suscripcion',
            summary:
                'Actualiza ciclo de cobro o plan usando controles de suscripcion.',
          ),
          'account_restore_purchases': const _LocalizedArticleOverride(
            title: 'Restaurar compras',
            summary:
                'Restaura compras previas despues de reinstalar o cambiar dispositivo.',
          ),
          'account_settings': const _LocalizedArticleOverride(
            title: 'Configuracion de cuenta',
            summary:
                'Gestiona preferencias de cuenta y opciones principales de perfil.',
          ),
        };
      default:
        return const {};
    }
  }
}

class _LocalizedArticleOverride {
  final String title;
  final String summary;
  final String? whatThisDoes;
  final String? whoShouldUseIt;
  final List<String>? steps;
  final List<String>? tips;
  final List<String>? commonIssues;

  const _LocalizedArticleOverride({
    required this.title,
    required this.summary,
    this.whatThisDoes,
    this.whoShouldUseIt,
    this.steps,
    this.tips,
    this.commonIssues,
  });
}
