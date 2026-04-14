class CategoryNode {
  final String slug;
  final String title;
  final String? parentSlug;
  final int sortOrder;
  final List<String> synonyms;

  const CategoryNode({
    required this.slug,
    required this.title,
    this.parentSlug,
    this.sortOrder = 0,
    this.synonyms = const [],
  });

  bool get isPrimary => parentSlug == null || parentSlug!.isEmpty;
}

class CategoryTaxonomy {
  // Primary categories are intentionally curated to avoid UI overload.
  static const List<CategoryNode> primary = [
    CategoryNode(slug: 'food-beverage', title: 'Food & Beverage', sortOrder: 10),
    CategoryNode(slug: 'retail-shopping', title: 'Retail & Shopping', sortOrder: 20),
    CategoryNode(slug: 'beauty-personal-care', title: 'Beauty & Personal Care', sortOrder: 30),
    CategoryNode(slug: 'health-wellness', title: 'Health & Wellness', sortOrder: 40),
    CategoryNode(slug: 'automotive', title: 'Automotive', sortOrder: 50),
    CategoryNode(slug: 'home-services', title: 'Home Services', sortOrder: 60),
    CategoryNode(slug: 'professional-services', title: 'Professional Services', sortOrder: 70),
    CategoryNode(slug: 'events-entertainment', title: 'Events & Entertainment', sortOrder: 80),
    CategoryNode(slug: 'travel-tourism', title: 'Travel & Tourism', sortOrder: 90),
    CategoryNode(slug: 'education-training', title: 'Education & Training', sortOrder: 100),
    CategoryNode(slug: 'real-estate-rentals', title: 'Real Estate & Rentals', sortOrder: 110),
    CategoryNode(slug: 'technology-electronics', title: 'Technology & Electronics', sortOrder: 120),
    CategoryNode(slug: 'agriculture-local-produce', title: 'Agriculture & Local Produce', sortOrder: 130),
    CategoryNode(slug: 'community-nonprofit', title: 'Community & Nonprofit', sortOrder: 140),
    CategoryNode(slug: 'other', title: 'Other', sortOrder: 150),
  ];

  static const List<CategoryNode> subcategories = [
    CategoryNode(slug: 'restaurants', title: 'Restaurants', parentSlug: 'food-beverage', sortOrder: 11),
    CategoryNode(slug: 'cafes-bakeries', title: 'Cafes & Bakeries', parentSlug: 'food-beverage', sortOrder: 12),
    CategoryNode(slug: 'catering', title: 'Catering', parentSlug: 'food-beverage', sortOrder: 13),
    CategoryNode(slug: 'bars-nightlife', title: 'Bars & Nightlife', parentSlug: 'food-beverage', sortOrder: 14),
    CategoryNode(slug: 'street-vending', title: 'Street Vending', parentSlug: 'food-beverage', sortOrder: 15),

    CategoryNode(slug: 'fashion-accessories', title: 'Fashion & Accessories', parentSlug: 'retail-shopping', sortOrder: 21),
    CategoryNode(slug: 'grocery-convenience', title: 'Grocery & Convenience', parentSlug: 'retail-shopping', sortOrder: 22),
    CategoryNode(slug: 'home-goods', title: 'Home Goods', parentSlug: 'retail-shopping', sortOrder: 23),
    CategoryNode(slug: 'gifts-specialty', title: 'Gifts & Specialty', parentSlug: 'retail-shopping', sortOrder: 24),

    CategoryNode(slug: 'hair-salon', title: 'Hair Salon', parentSlug: 'beauty-personal-care', sortOrder: 31),
    CategoryNode(slug: 'barber', title: 'Barber', parentSlug: 'beauty-personal-care', sortOrder: 32),
    CategoryNode(slug: 'nails-spa', title: 'Nails & Spa', parentSlug: 'beauty-personal-care', sortOrder: 33),
    CategoryNode(slug: 'cosmetics-skincare', title: 'Cosmetics & Skincare', parentSlug: 'beauty-personal-care', sortOrder: 34),

    CategoryNode(slug: 'fitness-gym', title: 'Fitness & Gym', parentSlug: 'health-wellness', sortOrder: 41),
    CategoryNode(slug: 'clinics-medical', title: 'Clinics & Medical', parentSlug: 'health-wellness', sortOrder: 42),
    CategoryNode(slug: 'therapy-counseling', title: 'Therapy & Counseling', parentSlug: 'health-wellness', sortOrder: 43),
    CategoryNode(slug: 'wellness-holistic', title: 'Wellness & Holistic', parentSlug: 'health-wellness', sortOrder: 44),

    CategoryNode(slug: 'mechanic-repair', title: 'Mechanic & Repair', parentSlug: 'automotive', sortOrder: 51),
    CategoryNode(slug: 'auto-parts', title: 'Auto Parts', parentSlug: 'automotive', sortOrder: 52),
    CategoryNode(slug: 'car-rentals', title: 'Car Rentals', parentSlug: 'automotive', sortOrder: 53),
    CategoryNode(slug: 'detailing-wash', title: 'Detailing & Wash', parentSlug: 'automotive', sortOrder: 54),

    CategoryNode(slug: 'plumbing-electrical', title: 'Plumbing & Electrical', parentSlug: 'home-services', sortOrder: 61),
    CategoryNode(slug: 'cleaning-maintenance', title: 'Cleaning & Maintenance', parentSlug: 'home-services', sortOrder: 62),
    CategoryNode(slug: 'construction-renovation', title: 'Construction & Renovation', parentSlug: 'home-services', sortOrder: 63),
    CategoryNode(slug: 'moving-delivery', title: 'Moving & Delivery', parentSlug: 'home-services', sortOrder: 64),

    CategoryNode(slug: 'legal-accounting', title: 'Legal & Accounting', parentSlug: 'professional-services', sortOrder: 71),
    CategoryNode(slug: 'marketing-media', title: 'Marketing & Media', parentSlug: 'professional-services', sortOrder: 72),
    CategoryNode(slug: 'consulting-business', title: 'Consulting & Business', parentSlug: 'professional-services', sortOrder: 73),
    CategoryNode(slug: 'admin-virtual-services', title: 'Admin & Virtual Services', parentSlug: 'professional-services', sortOrder: 74),

    CategoryNode(slug: 'event-planning', title: 'Event Planning', parentSlug: 'events-entertainment', sortOrder: 81),
    CategoryNode(slug: 'music-dj', title: 'Music & DJ', parentSlug: 'events-entertainment', sortOrder: 82),
    CategoryNode(slug: 'photography-videography', title: 'Photography & Videography', parentSlug: 'events-entertainment', sortOrder: 83),
    CategoryNode(slug: 'venues', title: 'Venues', parentSlug: 'events-entertainment', sortOrder: 84),

    CategoryNode(slug: 'tours-excursions', title: 'Tours & Excursions', parentSlug: 'travel-tourism', sortOrder: 91),
    CategoryNode(slug: 'accommodation', title: 'Accommodation', parentSlug: 'travel-tourism', sortOrder: 92),
    CategoryNode(slug: 'transport-airport', title: 'Transport & Airport', parentSlug: 'travel-tourism', sortOrder: 93),
    CategoryNode(slug: 'travel-services', title: 'Travel Services', parentSlug: 'travel-tourism', sortOrder: 94),

    CategoryNode(slug: 'tutoring', title: 'Tutoring', parentSlug: 'education-training', sortOrder: 101),
    CategoryNode(slug: 'skills-training', title: 'Skills Training', parentSlug: 'education-training', sortOrder: 102),
    CategoryNode(slug: 'online-courses', title: 'Online Courses', parentSlug: 'education-training', sortOrder: 103),
    CategoryNode(slug: 'coaching-mentorship', title: 'Coaching & Mentorship', parentSlug: 'education-training', sortOrder: 104),

    CategoryNode(slug: 'residential-sales-rentals', title: 'Residential Sales & Rentals', parentSlug: 'real-estate-rentals', sortOrder: 111),
    CategoryNode(slug: 'commercial-properties', title: 'Commercial Properties', parentSlug: 'real-estate-rentals', sortOrder: 112),
    CategoryNode(slug: 'property-management', title: 'Property Management', parentSlug: 'real-estate-rentals', sortOrder: 113),
    CategoryNode(slug: 'vacation-rentals', title: 'Vacation Rentals', parentSlug: 'real-estate-rentals', sortOrder: 114),

    CategoryNode(slug: 'phones-computers', title: 'Phones & Computers', parentSlug: 'technology-electronics', sortOrder: 121),
    CategoryNode(slug: 'it-services', title: 'IT Services', parentSlug: 'technology-electronics', sortOrder: 122),
    CategoryNode(slug: 'electronics-repair', title: 'Electronics Repair', parentSlug: 'technology-electronics', sortOrder: 123),
    CategoryNode(slug: 'software-development', title: 'Software Development', parentSlug: 'technology-electronics', sortOrder: 124),

    CategoryNode(slug: 'fresh-produce', title: 'Fresh Produce', parentSlug: 'agriculture-local-produce', sortOrder: 131),
    CategoryNode(slug: 'farming-supplies', title: 'Farming Supplies', parentSlug: 'agriculture-local-produce', sortOrder: 132),
    CategoryNode(slug: 'livestock', title: 'Livestock', parentSlug: 'agriculture-local-produce', sortOrder: 133),
    CategoryNode(slug: 'agri-services', title: 'Agriculture Services', parentSlug: 'agriculture-local-produce', sortOrder: 134),

    CategoryNode(slug: 'church-faith', title: 'Church & Faith', parentSlug: 'community-nonprofit', sortOrder: 141),
    CategoryNode(slug: 'charity-ngo', title: 'Charity & NGO', parentSlug: 'community-nonprofit', sortOrder: 142),
    CategoryNode(slug: 'clubs-groups', title: 'Clubs & Groups', parentSlug: 'community-nonprofit', sortOrder: 143),
    CategoryNode(slug: 'public-services', title: 'Public Services', parentSlug: 'community-nonprofit', sortOrder: 144),

    CategoryNode(slug: 'miscellaneous', title: 'Miscellaneous', parentSlug: 'other', sortOrder: 151),
  ];

  static const Map<String, String> legacyAliasToPrimarySlug = {
    'food & drink': 'food-beverage',
    'food and drink': 'food-beverage',
    'restaurants': 'food-beverage',
    'restaurant': 'food-beverage',
    'shopping': 'retail-shopping',
    'retail': 'retail-shopping',
    'beauty & spa': 'beauty-personal-care',
    'health & fitness': 'health-wellness',
    'automotive': 'automotive',
    'home services': 'home-services',
    'professional services': 'professional-services',
    'events': 'events-entertainment',
    'entertainment': 'events-entertainment',
    'travel & tourism': 'travel-tourism',
    'education': 'education-training',
    'real estate': 'real-estate-rentals',
    'electronics': 'technology-electronics',
    'accommodation': 'travel-tourism',
    'street vending': 'food-beverage',
  };

  static List<CategoryNode> allNodes() => [...primary, ...subcategories];

  static List<CategoryNode> subcategoriesForPrimary(String primarySlug) {
    return subcategories.where((n) => n.parentSlug == primarySlug).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  static String? resolvePrimarySlugFromLegacyLabel(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return legacyAliasToPrimarySlug[normalized];
  }
}
