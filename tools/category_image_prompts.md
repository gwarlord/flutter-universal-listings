# Category Image Prompt Pack

## Art Direction
- Format: square 1:1
- Style: vibrant Caribbean editorial illustration, clean composition
- Lighting: bright daylight, rich contrast, colorful but natural
- Composition: central subject, clear focal point, low clutter
- Output constraints: no text, no logos, no watermarks, no UI elements

## Global Prompt Prefix
Use this prefix before each category-specific line:

```
Vibrant Caribbean-inspired editorial illustration, square 1:1, clean composition, high detail, bright natural lighting, rich tropical color palette, modern marketplace category card visual, no text, no logo, no watermark.
```

## Per-Category Prompts
- food-beverage: Category Food & Beverage. Show appetizing Caribbean dishes, fresh produce, and market table styling. Avoid labels and branding.
- retail-shopping: Category Retail & Shopping. Show boutique storefront items, shopping bags, folded apparel, and lifestyle retail scene. Avoid labels and branding.
- beauty-personal-care: Category Beauty & Personal Care. Show salon tools, skincare textures, and beauty workspace. Avoid labels and branding.
- health-wellness: Category Health & Wellness. Show wellness clinic vibe, fitness accessories, and calming health-focused setting. Avoid labels and branding.
- automotive: Category Automotive. Show polished car details, tools, and service bay cues. Avoid labels and branding.
- home-services: Category Home Services. Show home maintenance tools, clean interior corner, and service-ready environment. Avoid labels and branding.
- professional-services: Category Professional Services. Show laptop, documents, office desk setup, consultation vibe. Avoid labels and branding.
- events-entertainment: Category Events & Entertainment. Show stage lighting, celebration decor, and event ambience. Avoid labels and branding.
- travel-tourism: Category Travel & Tourism. Show tropical destination cues, luggage, and excursion energy. Avoid labels and branding.
- education-training: Category Education & Training. Show books, notebook, training setup, and learning environment. Avoid labels and branding.
- real-estate-rentals: Category Real Estate & Rentals. Show property keys, architecture details, and modern home exterior cues. Avoid labels and branding.
- technology-electronics: Category Technology & Electronics. Show devices, cables, and sleek tech workspace. Avoid labels and branding.
- agriculture-local-produce: Category Agriculture & Local Produce. Show farm produce baskets, greenery, and market freshness. Avoid labels and branding.
- community-nonprofit: Category Community & Nonprofit. Show community gathering cues, supportive hands, civic activity feel. Avoid labels and branding.
- other: Category Other. Show mixed business symbols in a clean collage style. Avoid labels and branding.

- restaurants: Category Restaurants under Food & Beverage. Show plated dining and restaurant ambiance. Avoid labels and branding.
- cafes-bakeries: Category Cafes & Bakeries under Food & Beverage. Show pastries, coffee setup, and cozy cafe mood. Avoid labels and branding.
- catering: Category Catering under Food & Beverage. Show event buffet and plated service. Avoid labels and branding.
- fashion-accessories: Category Fashion & Accessories under Retail & Shopping. Show accessories and apparel styling. Avoid labels and branding.
- grocery-convenience: Category Grocery & Convenience under Retail & Shopping. Show produce shelves and everyday essentials. Avoid labels and branding.
- hair-salon: Category Hair Salon under Beauty & Personal Care. Show salon chair, styling tools, and haircare vibe. Avoid labels and branding.
- barber: Category Barber under Beauty & Personal Care. Show clippers, barber tools, and barbershop atmosphere. Avoid labels and branding.
- fitness-gym: Category Fitness & Gym under Health & Wellness. Show gym equipment and energetic workout setting. Avoid labels and branding.
- clinics-medical: Category Clinics & Medical under Health & Wellness. Show clean clinic tools and healthcare setting. Avoid labels and branding.
- mechanic-repair: Category Mechanic & Repair under Automotive. Show repair tools and engine detail. Avoid labels and branding.
- car-rentals: Category Car Rentals under Automotive. Show rental vehicle lineup and travel-ready car scene. Avoid labels and branding.
- plumbing-electrical: Category Plumbing & Electrical under Home Services. Show pipes, wiring, and service toolkit. Avoid labels and branding.
- construction-renovation: Category Construction & Renovation under Home Services. Show renovation tools and architectural materials. Avoid labels and branding.
- legal-accounting: Category Legal & Accounting under Professional Services. Show legal books, calculator, and desk setup. Avoid labels and branding.
- consulting-business: Category Consulting & Business under Professional Services. Show strategy board, laptop, and meeting context. Avoid labels and branding.
- event-planning: Category Event Planning under Events & Entertainment. Show decor planning board and event setup props. Avoid labels and branding.
- venues: Category Venues under Events & Entertainment. Show elegant event venue interior cues. Avoid labels and branding.
- tours-excursions: Category Tours & Excursions under Travel & Tourism. Show guide-led excursion visuals and tropical scenery. Avoid labels and branding.
- accommodation: Category Accommodation under Travel & Tourism. Show welcoming stay interior and hospitality feel. Avoid labels and branding.
- tutoring: Category Tutoring under Education & Training. Show one-on-one learning desk with study materials. Avoid labels and branding.
- skills-training: Category Skills Training under Education & Training. Show practical training environment and tools. Avoid labels and branding.
- residential-sales-rentals: Category Residential Sales & Rentals under Real Estate & Rentals. Show home frontage and keys. Avoid labels and branding.
- commercial-properties: Category Commercial Properties under Real Estate & Rentals. Show office/commercial building details. Avoid labels and branding.
- phones-computers: Category Phones & Computers under Technology & Electronics. Show devices and workstation setup. Avoid labels and branding.
- it-services: Category IT Services under Technology & Electronics. Show diagnostics screen and support desk context. Avoid labels and branding.
- fresh-produce: Category Fresh Produce under Agriculture & Local Produce. Show colorful produce baskets and market stand. Avoid labels and branding.
- farming-supplies: Category Farming Supplies under Agriculture & Local Produce. Show farm tools and supply materials. Avoid labels and branding.
- church-faith: Category Church & Faith under Community & Nonprofit. Show faith gathering ambiance and architectural cues. Avoid labels and branding.
- charity-ngo: Category Charity & NGO under Community & Nonprofit. Show volunteer support and donation activity cues. Avoid labels and branding.
- miscellaneous: Category Miscellaneous under Other. Show abstract multi-service visual motif. Avoid labels and branding.

## Quick Workflow
1. Generate all images using consistent model/style settings.
2. Upload final images to Firebase Storage or your CDN.
3. Fill photo URLs in tools/category_image_url_map.json.
4. Run tools/apply_category_image_urls.js in dry-run.
5. Run again with --commit.
