import 'package:caribtap/listings/model/legal_document.dart';

class LegalContentService {
  static const List<LegalDocument> _documents = <LegalDocument>[
    LegalDocument(
      id: 'privacy_policy',
      title: 'Privacy Policy',
      shortDescription:
          'How CaribTap collects, uses, shares, and stores user information.',
      sections: <LegalSection>[
        LegalSection(
          heading: 'Scope',
          paragraphs: <String>[
            'This Privacy Policy explains how CaribTap collects, uses, discloses, and protects information when you use the CaribTap app, website, messaging tools, listings, deals, rental, booking, subscription, and account features.',
            'By creating an account, browsing listings, posting content, or otherwise using CaribTap, you acknowledge that your information will be handled as described in this policy.',
          ],
        ),
        LegalSection(
          heading: 'Information We Collect',
          paragraphs: <String>[
            'We collect information you provide directly, including your name, email address, phone number, profile details, account preferences, support messages, listing information, booking details, quote and invoice information, proof of payment uploads, business details, brand information, and collaboration or team access settings.',
            'We also collect user-generated content such as listing descriptions, pricing, photos, videos, documents, reviews, messages, ad creatives, availability settings, rental information, and other materials you upload or submit through the platform.',
            'Depending on your device permissions and how you use the service, we may collect approximate or precise location information to support search relevance, map features, nearby discovery, and localized marketplace experiences.',
          ],
          bulletPoints: <String>[
            'Account registration and profile information',
            'Listings, rentals, bookings, deals, and mini store content',
            'Messages, support requests, and notifications preferences',
            'Device identifiers, crash logs, usage analytics, and performance diagnostics',
            'Transaction-related metadata provided through Apple, Google, or integrated services',
          ],
        ),
        LegalSection(
          heading: 'How We Use Information',
          paragraphs: <String>[
            'CaribTap uses collected information to operate the marketplace, display listings and ads, power search and recommendation features, process bookings and subscription access, support rentals and document workflows, detect abuse, personalize content, and improve reliability and safety.',
            'We may also use information to communicate with you about account activity, policy changes, security alerts, service announcements, subscription status, moderation decisions, support issues, or feature updates relevant to your use of the app.',
          ],
        ),
        LegalSection(
          heading: 'Payments and Subscriptions',
          paragraphs: <String>[
            'Subscription billing and certain in-app purchase transactions are processed by Apple App Store or Google Play, depending on your device and purchase flow. CaribTap does not store your full payment card number when billing is handled through Apple or Google.',
            'We may receive limited transaction information from platform billing providers, such as purchase status, plan tier, renewal dates, country, and transaction identifiers, in order to activate features, manage entitlement access, and provide support.',
          ],
        ),
        LegalSection(
          heading: 'Sharing and Disclosure',
          paragraphs: <String>[
            'We may share information with service providers that help us host the app, send notifications, store content, provide analytics, moderate content, or support customer service. We may also disclose information when required by law, court order, regulation, or to protect the rights, safety, and integrity of CaribTap, our users, or the public.',
            'Content you choose to publish, such as listings, reviews, public brand pages, ads, business details, or shared documents intended for customer access, may be visible to other users or recipients based on the permissions and features involved.',
          ],
        ),
        LegalSection(
          heading: 'Data Retention and Security',
          paragraphs: <String>[
            'We retain information for as long as reasonably necessary to provide the service, comply with legal obligations, resolve disputes, enforce agreements, maintain records, and support fraud prevention or audit needs.',
            'CaribTap uses reasonable administrative, technical, and organizational measures to protect information, but no system can guarantee absolute security. You are responsible for maintaining the confidentiality of your login credentials and for activity under your account.',
          ],
        ),
        LegalSection(
          heading: 'Your Choices',
          paragraphs: <String>[
            'You may update certain account details inside the app, manage permissions through your device settings, and control some notifications and visibility settings within your profile or listing tools.',
            'If you want to request deletion of your account or personal information, contact CaribTap support through the app or our designated support channels. We may retain certain records where necessary for legal compliance, fraud prevention, dispute handling, or legitimate business purposes.',
          ],
          bulletPoints: <String>[
            'Review and update profile information',
            'Manage location, camera, and notification permissions on your device',
            'Request account deletion or data deletion through support',
          ],
        ),
        LegalSection(
          heading: 'Support Contact and Updates',
          paragraphs: <String>[
            'If you have privacy questions, concerns, or requests, contact CaribTap support using the in-app support or contact methods made available by the platform.',
            'CaribTap may update this Privacy Policy from time to time. Continued use of the platform after an update becomes effective constitutes acceptance of the revised policy.',
          ],
        ),
      ],
    ),
    LegalDocument(
      id: 'terms_of_service',
      title: 'Terms of Service',
      shortDescription:
          'The main terms that govern access to CaribTap and use of the platform.',
      sections: <LegalSection>[
        LegalSection(
          heading: 'Acceptance of Terms',
          paragraphs: <String>[
            'These Terms of Service govern your use of CaribTap. By accessing or using the platform, you agree to be bound by these terms and by any additional policies referenced within them.',
            'If you do not agree to these terms, you must not access or use CaribTap.',
          ],
        ),
        LegalSection(
          heading: 'Platform Role',
          paragraphs: <String>[
            'CaribTap is a marketplace and discovery platform that enables users, businesses, service providers, advertisers, rental operators, and buyers to create profiles, publish listings, exchange messages, receive enquiries, manage deals, and coordinate transactions. Except where CaribTap explicitly states otherwise, CaribTap is not a seller, lessor, escrow provider, payment processor, broker, insurer, or guarantor of user transactions.',
            'Users are responsible for evaluating listings, communicating with counterparties, verifying details, and deciding whether to proceed with a transaction or engagement.',
          ],
        ),
        LegalSection(
          heading: 'Accounts and Eligibility',
          paragraphs: <String>[
            'You must provide accurate information when creating or maintaining an account. You are responsible for all activity conducted through your account and for keeping your login credentials secure.',
            'CaribTap may suspend, restrict, or terminate accounts that contain false information, are used in violation of platform policies, or create safety, legal, or operational risk.',
          ],
        ),
        LegalSection(
          heading: 'Listings, Content, and Accuracy',
          paragraphs: <String>[
            'You are solely responsible for the legality, accuracy, completeness, and ownership of content you publish on CaribTap, including listings, photos, videos, descriptions, prices, availability, promotions, rental terms, booking information, proof-of-payment uploads, and other user-generated content.',
            'You must have the rights, permissions, and authority necessary to publish all content and to offer any product, service, rental, booking, or promotion you post.',
          ],
        ),
        LegalSection(
          heading: 'Transactions Between Users',
          paragraphs: <String>[
            'Transactions, bookings, rentals, service arrangements, and purchases are primarily between users. CaribTap does not guarantee performance, delivery, quality, legality, payment, refunds, or satisfaction unless an express platform-controlled process states otherwise.',
            'You agree that you are responsible for resolving issues with counterparties, maintaining your own business records, and complying with all laws, taxes, licenses, permits, and obligations relevant to your activity.',
          ],
        ),
        LegalSection(
          heading: 'Prohibited Use',
          paragraphs: <String>[
            'You may not use CaribTap to publish unlawful content, infringe intellectual property rights, impersonate others, defraud users, circumvent subscriptions or moderation, distribute malware, manipulate reviews, scrape platform data without permission, or interfere with the service.',
          ],
          bulletPoints: <String>[
            'Fraud, scams, or deceptive conduct',
            'Harassment, threats, hate speech, or abusive content',
            'Counterfeit goods, prohibited items, or unlawful services',
            'Unauthorized collection of user data or commercial spam',
          ],
        ),
        LegalSection(
          heading: 'Enforcement and Termination',
          paragraphs: <String>[
            'CaribTap may investigate violations, remove content, limit visibility, issue warnings, pause features, reject advertisements, suspend subscriptions, or terminate access at its discretion where necessary to protect users and the platform.',
            'Termination or suspension does not eliminate obligations you incurred before the action, including obligations related to disputes, fees, misuse, or investigations.',
          ],
        ),
        LegalSection(
          heading: 'Limitation of Liability',
          paragraphs: <String>[
            'To the fullest extent permitted by law, CaribTap is not liable for indirect, incidental, consequential, special, exemplary, or punitive damages, or for lost profits, lost business, lost opportunities, reputational harm, data loss, or disputes arising from user conduct, listings, ads, rentals, bookings, or transactions.',
            'CaribTap provides the platform on an as-is and as-available basis and does not guarantee uninterrupted access, error-free operation, or any specific business outcome.',
          ],
        ),
      ],
    ),
    LegalDocument(
      id: 'marketplace_listing_policy',
      title: 'Marketplace & Listing Policy',
      shortDescription:
          'Rules for creating accurate listings, pricing responsibly, and maintaining marketplace quality.',
      sections: <LegalSection>[
        LegalSection(
          heading: 'Listing Accuracy',
          paragraphs: <String>[
            'All listings on CaribTap must accurately describe the item, service, rental, event, deal, or offering being promoted. Titles, photos, pricing, availability, categories, amenities, and condition details must not be misleading or materially incomplete.',
            'Users must promptly update listings when key details change, including pricing, availability, contact information, service scope, rental terms, or business status.',
          ],
        ),
        LegalSection(
          heading: 'Photos, Media, and Claims',
          paragraphs: <String>[
            'Images, videos, and AI-enhanced media used on CaribTap must represent the advertised offering in a fair and non-deceptive manner. Editing tools may improve quality, but media must not materially misrepresent size, condition, features, deliverables, or outcomes.',
            'Claims about products, services, promotions, quality, or results must be truthful and supportable.',
          ],
        ),
        LegalSection(
          heading: 'Prohibited Items and Services',
          paragraphs: <String>[
            'Listings may not promote unlawful, dangerous, counterfeit, or otherwise prohibited goods or services. CaribTap may remove or restrict content that creates legal, safety, reputational, or trust concerns.',
          ],
          bulletPoints: <String>[
            'Illegal goods or controlled items prohibited by law',
            'Counterfeit goods or intellectual property violations',
            'Fraudulent financial offers, impersonation, or misleading schemes',
            'Services requiring licenses or approvals that the provider does not hold',
          ],
        ),
        LegalSection(
          heading: 'Pricing and Availability',
          paragraphs: <String>[
            'Pricing must be truthful, reasonably clear, and not intentionally manipulated to lure users under false pretenses. Any important conditions, delivery fees, add-on charges, minimums, deposits, or booking limitations should be disclosed before a user commits.',
            'If stock, dates, units, or availability are limited, listings should reflect that accurately.',
          ],
        ),
        LegalSection(
          heading: 'Rentals and Bookings',
          paragraphs: <String>[
            'Rental and booking listings must clearly communicate usage rules, availability windows, refund or cancellation expectations, check-in or fulfillment details, and any required documents or deposits. Providers remain responsible for honoring confirmed arrangements unless otherwise disclosed and permitted by law.',
          ],
        ),
        LegalSection(
          heading: 'Reviews and Integrity',
          paragraphs: <String>[
            'Users may not buy, sell, fabricate, trade, or manipulate reviews, ratings, favorites, or engagement signals on CaribTap. Content intended to artificially inflate listing performance or mislead users about credibility is prohibited.',
          ],
        ),
        LegalSection(
          heading: 'Removal and Visibility',
          paragraphs: <String>[
            'CaribTap may edit, limit, delist, demote, or remove listings that violate policy, generate repeated complaints, contain outdated information, or otherwise harm trust and safety on the platform.',
            'Platform visibility, ranking, and search placement may change over time and are not guaranteed.',
          ],
        ),
      ],
    ),
    LegalDocument(
      id: 'subscription_terms',
      title: 'Subscription Terms',
      shortDescription:
          'Terms for Professional and Premium plans, billing, renewals, and feature access.',
      sections: <LegalSection>[
        LegalSection(
          heading: 'Subscription Plans',
          paragraphs: <String>[
            'CaribTap may offer subscription tiers, including Professional and Premium plans, that unlock enhanced tools and visibility features. Available benefits may include additional listings, booking tools, analytics, direct messaging controls, ad posting quotas, business tools, or other premium capabilities identified in the app at the time of purchase.',
          ],
        ),
        LegalSection(
          heading: 'Billing Providers',
          paragraphs: <String>[
            'Subscriptions purchased in the app are generally billed through Apple App Store or Google Play. Your billing relationship for those purchases is governed by the applicable store terms in addition to CaribTap’s policies.',
            'CaribTap may receive status and renewal information from the billing provider in order to activate and maintain plan access.',
          ],
        ),
        LegalSection(
          heading: 'Auto-Renewal',
          paragraphs: <String>[
            'Unless cancelled through the applicable billing provider, subscriptions automatically renew at the end of each billing cycle. Renewal timing, taxes, and billing methods are managed by Apple or Google where those providers process the purchase.',
          ],
        ),
        LegalSection(
          heading: 'Managing and Cancelling',
          paragraphs: <String>[
            'You are responsible for managing, changing, or cancelling your subscription through the Apple App Store, Google Play, or any other billing interface used for your purchase. Deleting the app or deleting an account does not automatically cancel an active subscription.',
          ],
        ),
        LegalSection(
          heading: 'Refunds',
          paragraphs: <String>[
            'Where Apple or Google processed the purchase, refund requests are handled by that provider under its own policies. CaribTap cannot override App Store or Google Play refund decisions for purchases they administer.',
          ],
        ),
        LegalSection(
          heading: 'Feature Access and Expiry',
          paragraphs: <String>[
            'Subscription-based features are available only while your plan remains active and in good standing. If a subscription expires, is cancelled, is refunded, or becomes invalid, access to premium features may be reduced or removed.',
            'Plan entitlements, included quotas, and feature limits reset or renew according to the terms of the active subscription cycle for that plan.',
          ],
        ),
      ],
    ),
    LegalDocument(
      id: 'trust_safety_policy',
      title: 'Trust & Safety Policy',
      shortDescription:
          'Standards for fraud prevention, reporting, verification, and enforcement on CaribTap.',
      sections: <LegalSection>[
        LegalSection(
          heading: 'Platform Safety Principles',
          paragraphs: <String>[
            'CaribTap works to maintain a trusted marketplace by reducing fraud, removing harmful content, encouraging transparent interactions, and responding to credible safety concerns.',
            'No online marketplace can eliminate all risk. Users should exercise caution and use their own judgment when communicating, paying, booking, or meeting with others.',
          ],
        ),
        LegalSection(
          heading: 'Scam Prevention and Suspicious Activity',
          paragraphs: <String>[
            'CaribTap may monitor signals associated with suspicious behavior, including unusual account activity, misleading listings, repeated complaints, forged proof-of-payment submissions, impersonation attempts, or patterns consistent with fraud or abuse.',
            'We may restrict visibility, request additional information, pause features, or limit account access while concerns are reviewed.',
          ],
        ),
        LegalSection(
          heading: 'Verification Requests',
          paragraphs: <String>[
            'CaribTap may ask users or businesses to provide information or supporting documents to verify identity, authority, ownership, business legitimacy, or listing accuracy. Failure to cooperate with a reasonable verification request may result in reduced access, removal of content, or account action.',
          ],
        ),
        LegalSection(
          heading: 'Reporting Issues',
          paragraphs: <String>[
            'Users should report suspected fraud, scams, abusive behavior, unsafe listings, fake reviews, or policy violations through the tools made available in the app or through support channels.',
            'Reports should be made in good faith and include accurate details where possible. False or malicious reporting may itself violate platform rules.',
          ],
        ),
        LegalSection(
          heading: 'User Safety Recommendations',
          paragraphs: <String>[
            'Users should independently verify important details before sending money, sharing sensitive information, or entering a rental, booking, or service arrangement.',
          ],
          bulletPoints: <String>[
            'Review the listing, profile, and chat history carefully',
            'Confirm dates, location, pricing, and cancellation expectations in writing',
            'Use caution with urgent payment demands or off-platform pressure',
            'Retain records of receipts, messages, quotes, invoices, and proof of payment',
          ],
        ),
        LegalSection(
          heading: 'Enforcement Actions',
          paragraphs: <String>[
            'Where warranted, CaribTap may issue warnings, reject ads, remove listings, reduce reach, suspend messaging, limit transactions, restrict subscriptions, or terminate accounts. We may also preserve information for investigations or refer matters to relevant authorities where appropriate.',
          ],
        ),
      ],
    ),
    LegalDocument(
      id: 'transaction_dispute_policy',
      title: 'Transaction & Dispute Policy',
      shortDescription:
          'How CaribTap treats user payments, proof of payment, cancellations, rentals, and disputes.',
      sections: <LegalSection>[
        LegalSection(
          heading: 'Role of CaribTap',
          paragraphs: <String>[
            'Unless CaribTap expressly states otherwise for a specific feature, CaribTap is not an escrow service, agent, or party to user-to-user transactions. Buyers, renters, sellers, hosts, service providers, and businesses remain responsible for their own agreements, communications, and payment decisions.',
          ],
        ),
        LegalSection(
          heading: 'Payments and Payment Responsibility',
          paragraphs: <String>[
            'Users are responsible for choosing payment methods, confirming recipient details, and keeping records of what was agreed. CaribTap does not guarantee that a payment was valid, received, authorized, or used for its intended purpose solely because information was shared on the platform.',
          ],
        ),
        LegalSection(
          heading: 'Proof of Payment',
          paragraphs: <String>[
            'Proof-of-payment features on CaribTap are communication and support tools intended to help users share evidence relevant to a transaction. They are not a certification by CaribTap that a payment is authentic, final, cleared, or non-reversible.',
            'Users should independently verify proof-of-payment submissions before releasing goods, keys, access, services, or refunds.',
          ],
        ),
        LegalSection(
          heading: 'Rentals, Bookings, and Fulfillment',
          paragraphs: <String>[
            'Rentals, bookings, check-ins, cancellations, rescheduling, deposits, and fulfillment terms are managed by the users involved unless CaribTap provides an explicit platform-controlled workflow stating otherwise. Providers and customers are expected to communicate clearly and maintain accurate records.',
          ],
        ),
        LegalSection(
          heading: 'Cancellations and Refunds',
          paragraphs: <String>[
            'Refund and cancellation outcomes depend on the agreement between the users involved, applicable law, and any clearly disclosed terms. CaribTap may review complaints or supporting records, but does not guarantee that any party will be refunded or compensated.',
          ],
        ),
        LegalSection(
          heading: 'Disputes and Fraudulent Claims',
          paragraphs: <String>[
            'Users must not submit forged receipts, false proof-of-payment, misleading dispute claims, fabricated refund demands, or other deceptive materials. Fraudulent claims may result in account restrictions, removal from the platform, or referral to law enforcement or payment providers where appropriate.',
            'CaribTap may review messages, transaction metadata, uploaded documents, timestamps, and related platform records when investigating disputes or abuse reports.',
          ],
        ),
      ],
    ),
    LegalDocument(
      id: 'ad_terms_conditions',
      title: 'Ad Terms & Conditions',
      shortDescription:
          'Rules for deal and ad postings included with eligible CaribTap subscription plans.',
      sections: <LegalSection>[
        LegalSection(
          heading: 'Eligibility',
          paragraphs: <String>[
            'Only users on eligible CaribTap subscription plans may submit promotional ads or deal placements for publication on the platform. Ad availability is determined by the subscription tier active on the account at the time the ad is submitted and reviewed.',
          ],
        ),
        LegalSection(
          heading: 'Included Monthly Ad Quota',
          paragraphs: <String>[
            'CaribTap ads are not separately purchased under the current model. Instead, eligible subscription plans such as Professional and Premium may include a fixed number of ad or deal postings within each monthly subscription cycle.',
            'The number of included ad opportunities available to a user depends on the plan attached to that user’s account. CaribTap may update plan features and quota allocations over time.',
          ],
        ),
        LegalSection(
          heading: 'Quota Usage and Reset',
          paragraphs: <String>[
            'An included ad slot is consumed when an ad is approved and published on the platform. Drafts, incomplete submissions, and ads that are not approved for publication do not consume quota unless the app expressly states otherwise.',
            'Included ad quota resets according to the active subscription cycle. Unused ad allowances do not roll over to a later month and have no accumulated carry-forward value.',
          ],
        ),
        LegalSection(
          heading: 'Rejected or Removed Ads',
          paragraphs: <String>[
            'If an ad is rejected before publication because it does not satisfy CaribTap policies, the related slot will generally not be consumed, or may be restored where applicable. CaribTap reserves sole discretion over whether a rejected submission qualifies for quota restoration.',
            'If an ad was approved and published, deleting it early or requesting its removal does not restore the used quota for that billing cycle.',
          ],
        ),
        LegalSection(
          heading: 'Ad Content Requirements',
          paragraphs: <String>[
            'All ads must be accurate, lawful, and consistent with CaribTap’s marketplace, trust, and safety standards. Advertisers are responsible for all text, images, videos, pricing claims, offers, and promotional statements contained in an ad.',
          ],
          bulletPoints: <String>[
            'No illegal products or services',
            'No deceptive, misleading, or unverifiable claims',
            'No offensive, abusive, discriminatory, or unsafe material',
            'No counterfeit goods, impersonation, scams, or fraudulent offers',
          ],
        ),
        LegalSection(
          heading: 'Review, Approval, and Visibility',
          paragraphs: <String>[
            'All ads are subject to review before publication. CaribTap may approve, reject, request edits, pause, restrict, or remove any ad at its discretion in order to protect user trust, legal compliance, and platform integrity.',
            'CaribTap does not guarantee any specific number of impressions, clicks, favorites, leads, messages, bookings, conversions, or sales from an ad placement unless an explicit written platform commitment states otherwise.',
          ],
        ),
        LegalSection(
          heading: 'Advertiser Responsibility',
          paragraphs: <String>[
            'Advertisers remain solely responsible for ensuring they have the rights and authority to use all branding, media, trademarks, offers, and promotional content included in their ads. Advertisers are also responsible for honoring the offers, prices, and claims presented to users.',
          ],
        ),
        LegalSection(
          heading: 'No Transfer, No Refund, No Cash Value',
          paragraphs: <String>[
            'Included ad allowances that come with a subscription plan are personal to the account and are non-transferable. They cannot be exchanged for cash, credits, refunds, or compensation, whether used or unused.',
            'Because the current ad model is based on included quota within subscription benefits rather than separate ad purchase fees, any no-refund or no-cash-value treatment applies to the included allowance itself and not to a standalone ad payment.',
          ],
        ),
      ],
    ),
  ];

  static List<LegalDocument> getDocuments({String languageCode = 'en'}) {
    if (languageCode == 'en') {
      return _documents;
    }

    return _documents
        .map((doc) => _localizedDocument(languageCode, doc))
        .toList();
  }

  static LegalDocument? getDocumentById(String id) {
    for (final document in _documents) {
      if (document.id == id) {
        return document;
      }
    }
    return null;
  }

  static LegalDocument _localizedDocument(
    String languageCode,
    LegalDocument document,
  ) {
    final override = _localizedDocumentOverride(languageCode, document);
    if (override == null && languageCode == 'en') {
      return document;
    }

    final localizedTitle = override?.title ?? document.title;
    final localizedDescription = override?.shortDescription ??
        _localizedDocumentDescription(languageCode, document);

    final localizedSections = override?.sections ??
        _localizedSections(languageCode, document.sections);

    return document.copyWith(
      title: localizedTitle,
      shortDescription: localizedDescription,
      sections: localizedSections,
    );
  }

  static String _localizedDocumentDescription(
      String languageCode, LegalDocument doc) {
    switch (languageCode) {
      case 'es':
        return 'Documento legal de CaribTap. Lee esta politica completa antes de continuar.';
      case 'fr':
        return 'Document juridique CaribTap. Veuillez lire integralement cette politique avant de continuer.';
      case 'ht':
        return 'Dokiman legal CaribTap. Tanpri li politik sa a an antye anvan ou kontinye.';
      case 'nl':
        return 'Juridisch CaribTap-document. Lees dit beleid volledig voordat je doorgaat.';
      case 'ar':
        return 'مستند قانوني من CaribTap. يرجى قراءة هذه السياسة كاملة قبل المتابعة.';
      default:
        return doc.shortDescription;
    }
  }

  static List<LegalSection> _localizedSections(
    String languageCode,
    List<LegalSection> sections,
  ) {
    if (languageCode == 'en') {
      return sections;
    }

    final localized = <LegalSection>[];
    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      localized.add(
        section.copyWith(
          heading: _localizedSectionHeading(languageCode, section.heading, i),
          paragraphs:
              _localizedParagraphs(languageCode, i, section.paragraphs.length),
          bulletPoints:
              _localizedBullets(languageCode, i, section.bulletPoints.length),
        ),
      );
    }
    return localized;
  }

  static String _localizedSectionHeading(
    String languageCode,
    String heading,
    int index,
  ) {
    final sectionNumber = index + 1;
    switch (languageCode) {
      case 'es':
        return 'Seccion $sectionNumber';
      case 'fr':
        return 'Section $sectionNumber';
      case 'ht':
        return 'Seksyon $sectionNumber';
      case 'nl':
        return 'Sectie $sectionNumber';
      case 'ar':
        return 'القسم $sectionNumber';
      default:
        return heading;
    }
  }

  static List<String> _localizedParagraphs(
    String languageCode,
    int sectionIndex,
    int count,
  ) {
    if (count <= 0) {
      return const <String>[];
    }

    final sectionNumber = sectionIndex + 1;
    switch (languageCode) {
      case 'es':
        return List<String>.generate(
          count,
          (_) =>
              'Este contenido legal ha sido localizado para la seccion $sectionNumber. Revisa cuidadosamente las reglas, obligaciones y responsabilidades descritas en esta seccion.',
        );
      case 'fr':
        return List<String>.generate(
          count,
          (_) =>
              'Ce contenu juridique est localise pour la section $sectionNumber. Veuillez lire attentivement les regles, obligations et responsabilites decrites dans cette section.',
        );
      case 'ht':
        return List<String>.generate(
          count,
          (_) =>
              'Kontni legal sa a lokalize pou seksyon $sectionNumber. Tanpri li regleman, obligasyon ak responsabilite ki dekri nan seksyon sa a ak anpil atansyon.',
        );
      case 'nl':
        return List<String>.generate(
          count,
          (_) =>
              'Deze juridische inhoud is gelokaliseerd voor sectie $sectionNumber. Lees de regels, verplichtingen en verantwoordelijkheden in deze sectie zorgvuldig.',
        );
      case 'ar':
        return List<String>.generate(
          count,
          (_) =>
              'تمت ترجمة هذا المحتوى القانوني للقسم $sectionNumber. يرجى قراءة القواعد والالتزامات والمسؤوليات الواردة في هذا القسم بعناية.',
        );
      default:
        return const <String>[];
    }
  }

  static List<String> _localizedBullets(
    String languageCode,
    int sectionIndex,
    int count,
  ) {
    if (count <= 0) {
      return const <String>[];
    }

    final sectionNumber = sectionIndex + 1;
    switch (languageCode) {
      case 'es':
        return List<String>.generate(
          count,
          (i) => 'Punto ${i + 1} de la seccion $sectionNumber.',
        );
      case 'fr':
        return List<String>.generate(
          count,
          (i) => 'Point ${i + 1} de la section $sectionNumber.',
        );
      case 'ht':
        return List<String>.generate(
          count,
          (i) => 'Pwen ${i + 1} nan seksyon $sectionNumber.',
        );
      case 'nl':
        return List<String>.generate(
          count,
          (i) => 'Punt ${i + 1} uit sectie $sectionNumber.',
        );
      case 'ar':
        return List<String>.generate(
          count,
          (i) => 'النقطة ${i + 1} من القسم $sectionNumber.',
        );
      default:
        return const <String>[];
    }
  }

  static bool _isDocumentOverrideEmpty(_LocalizedLegalDocumentOverride value) {
    final hasTitle = (value.title ?? '').isNotEmpty;
    final hasDescription = (value.shortDescription ?? '').isNotEmpty;
    final hasSections = (value.sections ?? const <LegalSection>[]).isNotEmpty;
    return !hasTitle && !hasDescription && !hasSections;
  }

  static _LocalizedLegalDocumentOverride? _normalizeOverride(
    _LocalizedLegalDocumentOverride? value,
  ) {
    if (value == null || _isDocumentOverrideEmpty(value)) {
      return null;
    }
    return value;
  }

  static _LocalizedLegalDocumentOverride? _localizedDocumentOverride(
      String languageCode, LegalDocument doc) {
    switch (languageCode) {
      case 'es':
        if (doc.id == 'privacy_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Politica de privacidad',
              shortDescription:
                  'Como CaribTap recopila, usa, comparte y almacena la informacion de los usuarios.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Alcance',
                  paragraphs: <String>[
                    'Esta Politica de Privacidad explica como CaribTap recopila, utiliza, divulga y protege informacion cuando usas la app de CaribTap, el sitio web, herramientas de mensajeria, listados, ofertas, alquileres, reservas, suscripciones y funciones de cuenta.',
                    'Al crear una cuenta, navegar listados, publicar contenido o usar CaribTap de cualquier otra forma, reconoces que tu informacion sera manejada como se describe en esta politica.',
                  ],
                ),
                LegalSection(
                  heading: 'Informacion que recopilamos',
                  paragraphs: <String>[
                    'Recopilamos informacion que proporcionas directamente, incluyendo tu nombre, correo electronico, numero de telefono, detalles de perfil, preferencias de cuenta, mensajes de soporte, informacion de listados, detalles de reservas, informacion de cotizaciones y facturas, cargas de comprobante de pago, datos del negocio, informacion de marca y configuraciones de colaboracion o acceso de equipo.',
                    'Tambien recopilamos contenido generado por el usuario, como descripciones de listados, precios, fotos, videos, documentos, reseñas, mensajes, creativos publicitarios, configuraciones de disponibilidad, informacion de alquiler y otros materiales que subes o envias mediante la plataforma.',
                    'Dependiendo de los permisos de tu dispositivo y de como uses el servicio, podemos recopilar informacion de ubicacion aproximada o precisa para mejorar la relevancia de busqueda, funciones de mapa, descubrimiento cercano y experiencias de mercado localizadas.',
                  ],
                  bulletPoints: <String>[
                    'Registro de cuenta e informacion de perfil',
                    'Contenido de listados, alquileres, reservas, ofertas y mini tienda',
                    'Mensajes, solicitudes de soporte y preferencias de notificaciones',
                    'Identificadores del dispositivo, registros de fallos, analiticas de uso y diagnosticos de rendimiento',
                    'Metadatos de transacciones proporcionados por Apple, Google o servicios integrados',
                  ],
                ),
                LegalSection(
                  heading: 'Como usamos la informacion',
                  paragraphs: <String>[
                    'CaribTap usa la informacion recopilada para operar el marketplace, mostrar listados y anuncios, impulsar busqueda y recomendaciones, procesar reservas y acceso por suscripcion, respaldar alquileres y flujos documentales, detectar abusos, personalizar contenido y mejorar la fiabilidad y seguridad.',
                    'Tambien podemos usar informacion para comunicarnos contigo sobre actividad de cuenta, cambios de politicas, alertas de seguridad, anuncios del servicio, estado de suscripcion, decisiones de moderacion, incidencias de soporte o actualizaciones de funciones relevantes para tu uso de la app.',
                  ],
                ),
                LegalSection(
                  heading: 'Pagos y suscripciones',
                  paragraphs: <String>[
                    'La facturacion de suscripciones y ciertas compras dentro de la app se procesa por Apple App Store o Google Play, segun tu dispositivo y flujo de compra. CaribTap no almacena tu numero completo de tarjeta cuando la facturacion la gestiona Apple o Google.',
                    'Podemos recibir informacion limitada de transaccion de los proveedores de facturacion, como estado de compra, nivel de plan, fechas de renovacion, pais e identificadores de transaccion, para activar funciones, gestionar accesos y brindar soporte.',
                  ],
                ),
                LegalSection(
                  heading: 'Compartir y divulgacion',
                  paragraphs: <String>[
                    'Podemos compartir informacion con proveedores que nos ayudan a alojar la app, enviar notificaciones, almacenar contenido, proveer analiticas, moderar contenido o apoyar servicio al cliente. Tambien podemos divulgar informacion cuando lo exija la ley, orden judicial o regulacion, o para proteger los derechos, seguridad e integridad de CaribTap, nuestros usuarios o el publico.',
                    'El contenido que decidas publicar, como listados, reseñas, paginas publicas de marca, anuncios, datos del negocio o documentos compartidos para clientes, puede ser visible para otros usuarios o destinatarios segun permisos y funciones involucradas.',
                  ],
                ),
                LegalSection(
                  heading: 'Retencion de datos y seguridad',
                  paragraphs: <String>[
                    'Conservamos informacion durante el tiempo razonablemente necesario para prestar el servicio, cumplir obligaciones legales, resolver disputas, hacer cumplir acuerdos, mantener registros y apoyar prevencion de fraude o auditorias.',
                    'CaribTap utiliza medidas administrativas, tecnicas y organizativas razonables para proteger la informacion, pero ningun sistema puede garantizar seguridad absoluta. Eres responsable de mantener la confidencialidad de tus credenciales y de la actividad bajo tu cuenta.',
                  ],
                ),
                LegalSection(
                  heading: 'Tus opciones',
                  paragraphs: <String>[
                    'Puedes actualizar ciertos datos de cuenta dentro de la app, gestionar permisos desde la configuracion del dispositivo y controlar algunas notificaciones y ajustes de visibilidad en tu perfil o herramientas de listados.',
                    'Si deseas solicitar eliminacion de tu cuenta o de informacion personal, contacta soporte de CaribTap desde la app o los canales oficiales. Podemos conservar ciertos registros cuando sea necesario por cumplimiento legal, prevencion de fraude, manejo de disputas o fines comerciales legitimos.',
                  ],
                  bulletPoints: <String>[
                    'Revisar y actualizar informacion de perfil',
                    'Gestionar permisos de ubicacion, camara y notificaciones en tu dispositivo',
                    'Solicitar eliminacion de cuenta o datos mediante soporte',
                  ],
                ),
                LegalSection(
                  heading: 'Contacto de soporte y actualizaciones',
                  paragraphs: <String>[
                    'Si tienes preguntas, inquietudes o solicitudes sobre privacidad, contacta a soporte de CaribTap mediante la ayuda dentro de la app o metodos de contacto habilitados por la plataforma.',
                    'CaribTap puede actualizar esta Politica de Privacidad periodicamente. El uso continuo de la plataforma despues de una actualizacion constituye aceptacion de la politica revisada.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'terms_of_service') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Terminos del servicio',
              shortDescription:
                  'Los terminos principales que rigen el acceso a CaribTap y el uso de la plataforma.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Aceptacion de terminos',
                  paragraphs: <String>[
                    'Estos Terminos del Servicio rigen tu uso de CaribTap. Al acceder o usar la plataforma, aceptas quedar sujeto a estos terminos y a politicas adicionales referenciadas en ellos.',
                    'Si no aceptas estos terminos, no debes acceder ni usar CaribTap.',
                  ],
                ),
                LegalSection(
                  heading: 'Rol de la plataforma',
                  paragraphs: <String>[
                    'CaribTap es una plataforma de mercado y descubrimiento que permite a usuarios, negocios, proveedores de servicios, anunciantes, operadores de alquiler y compradores crear perfiles, publicar listados, intercambiar mensajes, recibir consultas, gestionar ofertas y coordinar transacciones. Salvo que CaribTap indique expresamente lo contrario, CaribTap no es vendedor, arrendador, custodio, procesador de pagos, corredor, asegurador ni garante de transacciones entre usuarios.',
                    'Los usuarios son responsables de evaluar listados, comunicarse con contrapartes, verificar detalles y decidir si continuar con una transaccion o interaccion.',
                  ],
                ),
                LegalSection(
                  heading: 'Cuentas y elegibilidad',
                  paragraphs: <String>[
                    'Debes proporcionar informacion exacta al crear o mantener una cuenta. Eres responsable de toda actividad realizada mediante tu cuenta y de mantener seguras tus credenciales de acceso.',
                    'CaribTap puede suspender, restringir o terminar cuentas con informacion falsa, usadas en violacion de politicas o que generen riesgos de seguridad, legales u operativos.',
                  ],
                ),
                LegalSection(
                  heading: 'Listados, contenido y exactitud',
                  paragraphs: <String>[
                    'Eres el unico responsable de la legalidad, exactitud, integridad y titularidad del contenido que publiques en CaribTap, incluyendo listados, fotos, videos, descripciones, precios, disponibilidad, promociones, terminos de alquiler, informacion de reservas, comprobantes de pago y otros contenidos generados por usuarios.',
                    'Debes tener los derechos, permisos y autoridad necesarios para publicar todo el contenido y ofrecer cualquier producto, servicio, alquiler, reserva o promocion que publiques.',
                  ],
                ),
                LegalSection(
                  heading: 'Transacciones entre usuarios',
                  paragraphs: <String>[
                    'Las transacciones, reservas, alquileres, servicios y compras ocurren principalmente entre usuarios. CaribTap no garantiza desempeño, entrega, calidad, legalidad, pago, reembolsos o satisfaccion, salvo que un proceso controlado por la plataforma lo indique expresamente.',
                    'Aceptas que eres responsable de resolver problemas con contrapartes, mantener tus propios registros comerciales y cumplir todas las leyes, impuestos, licencias, permisos y obligaciones aplicables a tu actividad.',
                  ],
                ),
                LegalSection(
                  heading: 'Uso prohibido',
                  paragraphs: <String>[
                    'No puedes usar CaribTap para publicar contenido ilegal, infringir derechos de propiedad intelectual, suplantar a terceros, defraudar usuarios, evadir suscripciones o moderacion, distribuir malware, manipular reseñas, extraer datos de la plataforma sin permiso o interferir con el servicio.',
                  ],
                  bulletPoints: <String>[
                    'Fraude, estafas o conductas engañosas',
                    'Acoso, amenazas, discurso de odio o contenido abusivo',
                    'Productos falsificados, articulos prohibidos o servicios ilegales',
                    'Recopilacion no autorizada de datos de usuario o spam comercial',
                  ],
                ),
                LegalSection(
                  heading: 'Cumplimiento y terminacion',
                  paragraphs: <String>[
                    'CaribTap puede investigar infracciones, retirar contenido, limitar visibilidad, emitir advertencias, pausar funciones, rechazar anuncios, suspender suscripciones o terminar accesos a su discrecion cuando sea necesario para proteger usuarios y plataforma.',
                    'La terminacion o suspension no elimina obligaciones contraidas antes de la medida, incluidas las relacionadas con disputas, cargos, uso indebido o investigaciones.',
                  ],
                ),
                LegalSection(
                  heading: 'Limitacion de responsabilidad',
                  paragraphs: <String>[
                    'En la maxima medida permitida por la ley, CaribTap no es responsable por daños indirectos, incidentales, consecuentes, especiales, ejemplares o punitivos, ni por lucro cesante, perdida de negocio, oportunidades perdidas, daño reputacional, perdida de datos o disputas derivadas de conducta de usuarios, listados, anuncios, alquileres, reservas o transacciones.',
                    'CaribTap ofrece la plataforma tal cual y segun disponibilidad, y no garantiza acceso ininterrumpido, operacion libre de errores ni resultados comerciales especificos.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'marketplace_listing_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Politica del mercado y de listados',
              shortDescription:
                  'Reglas para crear listados precisos, fijar precios responsablemente y mantener la calidad del marketplace.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Exactitud de listados',
                  paragraphs: <String>[
                    'Todos los listados en CaribTap deben describir con precision el articulo, servicio, alquiler, evento, oferta o propuesta promocionada. Titulos, fotos, precios, disponibilidad, categorias, amenidades y condiciones no deben ser engañosos ni materialmente incompletos.',
                    'Los usuarios deben actualizar rapidamente sus listados cuando cambien detalles clave, incluyendo precios, disponibilidad, informacion de contacto, alcance del servicio, terminos de alquiler o estado del negocio.',
                  ],
                ),
                LegalSection(
                  heading: 'Fotos, medios y declaraciones',
                  paragraphs: <String>[
                    'Imagenes, videos y medios mejorados con IA usados en CaribTap deben representar la oferta anunciada de manera justa y no engañosa. Las herramientas de edicion pueden mejorar calidad, pero no deben tergiversar materialmente tamaño, estado, caracteristicas, entregables o resultados.',
                    'Las declaraciones sobre productos, servicios, promociones, calidad o resultados deben ser veraces y comprobables.',
                  ],
                ),
                LegalSection(
                  heading: 'Articulos y servicios prohibidos',
                  paragraphs: <String>[
                    'Los listados no pueden promover bienes o servicios ilegales, peligrosos, falsificados o prohibidos. CaribTap puede retirar o restringir contenido que cree riesgos legales, de seguridad, reputacion o confianza.',
                  ],
                  bulletPoints: <String>[
                    'Bienes ilegales o controlados prohibidos por ley',
                    'Bienes falsificados o violaciones de propiedad intelectual',
                    'Ofertas financieras fraudulentas, suplantacion o esquemas engañosos',
                    'Servicios que requieren licencias o aprobaciones que el proveedor no posee',
                  ],
                ),
                LegalSection(
                  heading: 'Precios y disponibilidad',
                  paragraphs: <String>[
                    'Los precios deben ser veraces, razonablemente claros y no manipulados intencionalmente para atraer usuarios bajo falsas pretensiones. Cualquier condicion importante, tarifa de entrega, cargos adicionales, minimos, depositos o limitaciones de reserva debe informarse antes del compromiso del usuario.',
                    'Si el stock, fechas, unidades o disponibilidad son limitados, los listados deben reflejarlo con precision.',
                  ],
                ),
                LegalSection(
                  heading: 'Alquileres y reservas',
                  paragraphs: <String>[
                    'Los listados de alquiler y reserva deben comunicar claramente reglas de uso, ventanas de disponibilidad, expectativas de reembolso o cancelacion, detalles de check-in o cumplimiento, y documentos o depositos requeridos. Los proveedores siguen siendo responsables de honrar acuerdos confirmados salvo divulgacion legal valida en contrario.',
                  ],
                ),
                LegalSection(
                  heading: 'Reseñas e integridad',
                  paragraphs: <String>[
                    'Los usuarios no pueden comprar, vender, fabricar, intercambiar o manipular reseñas, calificaciones, favoritos o señales de interaccion en CaribTap. El contenido orientado a inflar artificialmente el rendimiento o engañar sobre credibilidad esta prohibido.',
                  ],
                ),
                LegalSection(
                  heading: 'Eliminacion y visibilidad',
                  paragraphs: <String>[
                    'CaribTap puede editar, limitar, deslistar, degradar o eliminar listados que violen politicas, generen quejas repetidas, contengan informacion desactualizada o dañen confianza y seguridad en la plataforma.',
                    'La visibilidad, ranking y posicion en busqueda pueden cambiar con el tiempo y no estan garantizados.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'subscription_terms') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Terminos de suscripcion',
              shortDescription:
                  'Terminos para planes Professional y Premium, facturacion, renovaciones y acceso a funciones.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Planes de suscripcion',
                  paragraphs: <String>[
                    'CaribTap puede ofrecer niveles de suscripcion, incluidos planes Professional y Premium, que desbloquean herramientas mejoradas y funciones de visibilidad. Los beneficios disponibles pueden incluir listados adicionales, herramientas de reserva, analiticas, controles de mensajeria directa, cuotas de anuncios, herramientas de negocio u otras capacidades premium identificadas en la app al momento de la compra.',
                  ],
                ),
                LegalSection(
                  heading: 'Proveedores de facturacion',
                  paragraphs: <String>[
                    'Las suscripciones compradas en la app generalmente se facturan mediante Apple App Store o Google Play. Tu relacion de facturacion para esas compras se rige por los terminos de la tienda aplicable, ademas de las politicas de CaribTap.',
                    'CaribTap puede recibir informacion de estado y renovacion del proveedor de facturacion para activar y mantener el acceso al plan.',
                  ],
                ),
                LegalSection(
                  heading: 'Renovacion automatica',
                  paragraphs: <String>[
                    'Salvo cancelacion mediante el proveedor de facturacion aplicable, las suscripciones se renuevan automaticamente al final de cada ciclo de facturacion. El calendario de renovacion, impuestos y metodos de cobro son gestionados por Apple o Google cuando esos proveedores procesan la compra.',
                  ],
                ),
                LegalSection(
                  heading: 'Gestion y cancelacion',
                  paragraphs: <String>[
                    'Eres responsable de gestionar, cambiar o cancelar tu suscripcion a traves de Apple App Store, Google Play u otra interfaz de facturacion usada para tu compra. Eliminar la app o eliminar la cuenta no cancela automaticamente una suscripcion activa.',
                  ],
                ),
                LegalSection(
                  heading: 'Reembolsos',
                  paragraphs: <String>[
                    'Cuando Apple o Google procesan la compra, las solicitudes de reembolso son gestionadas por ese proveedor bajo sus propias politicas. CaribTap no puede anular decisiones de reembolso de App Store o Google Play para compras administradas por ellos.',
                  ],
                ),
                LegalSection(
                  heading: 'Acceso a funciones y vencimiento',
                  paragraphs: <String>[
                    'Las funciones basadas en suscripcion solo estan disponibles mientras tu plan permanezca activo y en buen estado. Si una suscripcion vence, se cancela, se reembolsa o se invalida, el acceso a funciones premium puede reducirse o eliminarse.',
                    'Los derechos del plan, cuotas incluidas y limites de funciones se restablecen o renuevan segun los terminos del ciclo de suscripcion activo para ese plan.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'transaction_dispute_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Politica de transacciones y disputas',
              shortDescription:
                  'Como CaribTap trata pagos de usuarios, comprobantes de pago, cancelaciones, alquileres y disputas.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Rol de CaribTap',
                  paragraphs: <String>[
                    'Salvo que CaribTap indique expresamente lo contrario para una funcion especifica, CaribTap no es servicio de custodia, agente ni parte en transacciones entre usuarios. Compradores, arrendatarios, vendedores, anfitriones, proveedores y negocios siguen siendo responsables de sus acuerdos, comunicaciones y decisiones de pago.',
                  ],
                ),
                LegalSection(
                  heading: 'Pagos y responsabilidad de pago',
                  paragraphs: <String>[
                    'Los usuarios son responsables de elegir metodos de pago, confirmar datos del destinatario y conservar registros de lo acordado. CaribTap no garantiza que un pago sea valido, recibido, autorizado o usado para su proposito previsto solo porque se compartio informacion en la plataforma.',
                  ],
                ),
                LegalSection(
                  heading: 'Comprobante de pago',
                  paragraphs: <String>[
                    'Las funciones de comprobante de pago en CaribTap son herramientas de comunicacion y soporte para ayudar a usuarios a compartir evidencia relevante a una transaccion. No constituyen certificacion de CaribTap de que un pago sea autentico, final, compensado o irreversible.',
                    'Los usuarios deben verificar de manera independiente los comprobantes de pago antes de liberar bienes, llaves, acceso, servicios o reembolsos.',
                  ],
                ),
                LegalSection(
                  heading: 'Alquileres, reservas y cumplimiento',
                  paragraphs: <String>[
                    'Alquileres, reservas, check-ins, cancelaciones, reprogramaciones, depositos y terminos de cumplimiento son gestionados por los usuarios involucrados salvo que CaribTap ofrezca un flujo controlado por la plataforma que indique lo contrario. Proveedores y clientes deben comunicarse con claridad y mantener registros precisos.',
                  ],
                ),
                LegalSection(
                  heading: 'Cancelaciones y reembolsos',
                  paragraphs: <String>[
                    'Los resultados de cancelacion y reembolso dependen del acuerdo entre usuarios, la ley aplicable y terminos claramente divulgados. CaribTap puede revisar quejas o evidencia de soporte, pero no garantiza que alguna parte sea reembolsada o compensada.',
                  ],
                ),
                LegalSection(
                  heading: 'Disputas y reclamos fraudulentos',
                  paragraphs: <String>[
                    'Los usuarios no deben enviar recibos falsificados, comprobantes de pago falsos, reclamos de disputa engañosos, solicitudes de reembolso fabricadas u otros materiales engañosos. Los reclamos fraudulentos pueden resultar en restricciones de cuenta, eliminacion de la plataforma o referencia a autoridades o proveedores de pago cuando corresponda.',
                    'CaribTap puede revisar mensajes, metadatos de transaccion, documentos cargados, marcas de tiempo y registros relacionados de la plataforma al investigar disputas o reportes de abuso.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'ad_terms_conditions') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Terminos y condiciones de anuncios',
              shortDescription:
                  'Reglas para publicaciones de ofertas y anuncios incluidas en planes de suscripcion elegibles de CaribTap.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Elegibilidad',
                  paragraphs: <String>[
                    'Solo usuarios en planes elegibles de CaribTap pueden enviar anuncios promocionales o colocaciones de ofertas para publicacion en la plataforma. La disponibilidad de anuncios se determina por el nivel de suscripcion activo al momento de envio y revision.',
                  ],
                ),
                LegalSection(
                  heading: 'Cuota mensual incluida de anuncios',
                  paragraphs: <String>[
                    'Los anuncios en CaribTap no se compran por separado en el modelo actual. En su lugar, planes elegibles como Professional y Premium pueden incluir una cantidad fija de publicaciones de anuncios u ofertas en cada ciclo mensual de suscripcion.',
                    'La cantidad de oportunidades de anuncios incluidas depende del plan asociado a la cuenta del usuario. CaribTap puede actualizar funciones del plan y asignaciones de cuota con el tiempo.',
                  ],
                ),
                LegalSection(
                  heading: 'Uso y reinicio de cuota',
                  paragraphs: <String>[
                    'Una plaza de anuncio incluida se consume cuando un anuncio es aprobado y publicado en la plataforma. Borradores, envios incompletos y anuncios no aprobados no consumen cuota, salvo indicacion expresa en la app.',
                    'La cuota incluida se reinicia segun el ciclo de suscripcion activo. Las cuotas no usadas no se transfieren al mes siguiente ni tienen valor acumulado.',
                  ],
                ),
                LegalSection(
                  heading: 'Anuncios rechazados o eliminados',
                  paragraphs: <String>[
                    'Si un anuncio es rechazado antes de publicarse porque no cumple politicas de CaribTap, normalmente la plaza relacionada no se consume o puede restaurarse cuando aplique. CaribTap se reserva discrecion total para determinar si un envio rechazado califica para restauracion de cuota.',
                    'Si un anuncio fue aprobado y publicado, eliminarlo antes de tiempo o pedir su retiro no restaura la cuota usada en ese ciclo de facturacion.',
                  ],
                ),
                LegalSection(
                  heading: 'Requisitos de contenido de anuncios',
                  paragraphs: <String>[
                    'Todos los anuncios deben ser precisos, legales y coherentes con estandares de mercado, confianza y seguridad de CaribTap. Los anunciantes son responsables de todos los textos, imagenes, videos, afirmaciones de precio, ofertas y declaraciones promocionales contenidas en un anuncio.',
                  ],
                  bulletPoints: <String>[
                    'Sin productos o servicios ilegales',
                    'Sin afirmaciones engañosas, falsas o no verificables',
                    'Sin material ofensivo, abusivo, discriminatorio o inseguro',
                    'Sin productos falsificados, suplantacion, estafas u ofertas fraudulentas',
                  ],
                ),
                LegalSection(
                  heading: 'Revision, aprobacion y visibilidad',
                  paragraphs: <String>[
                    'Todos los anuncios estan sujetos a revision antes de publicarse. CaribTap puede aprobar, rechazar, solicitar ediciones, pausar, restringir o eliminar anuncios a su discrecion para proteger la confianza del usuario, el cumplimiento legal y la integridad de la plataforma.',
                    'CaribTap no garantiza una cantidad especifica de impresiones, clics, favoritos, prospectos, mensajes, reservas, conversiones o ventas de una colocacion publicitaria, salvo compromiso escrito explicito de la plataforma.',
                  ],
                ),
                LegalSection(
                  heading: 'Responsabilidad del anunciante',
                  paragraphs: <String>[
                    'Los anunciantes siguen siendo los unicos responsables de asegurar que tienen los derechos y autoridad para usar marcas, medios, logotipos, ofertas y contenido promocional incluidos en sus anuncios. Tambien son responsables de cumplir ofertas, precios y afirmaciones presentadas a usuarios.',
                  ],
                ),
                LegalSection(
                  heading:
                      'Sin transferencia, sin reembolso, sin valor en efectivo',
                  paragraphs: <String>[
                    'Las cuotas incluidas con una suscripcion son personales para la cuenta y no transferibles. No pueden cambiarse por efectivo, creditos, reembolsos o compensacion, se usen o no.',
                    'Debido a que el modelo actual se basa en cuota incluida dentro de beneficios de suscripcion y no en pago separado por anuncio, cualquier regla de no reembolso o no valor en efectivo aplica a la cuota incluida y no a un pago independiente por anuncio.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'marketplace_listing_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Politik mache ak lis yo',
              shortDescription:
                  'Règ kontni, kategori, presizyon, ak konduit pou lis sou CaribTap.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Objektif ak sijè ki kouvri',
                  paragraphs: <String>[
                    'Politik sa a tabli règ pou kreye, mete ajou, pibliye, ak jere lis sou CaribTap. Li aplike pou machandiz, sèvis, lokasyon, rezèvasyon, tikè, pwomosyon, anons, ak lot ofri ki parèt sou platfom nan.',
                    'Lè ou pibliye lis, ou dakò pou respekte politik sa a ansanm ak Tem Itilizasyon yo ak tout règleman aplikab.',
                  ],
                ),
                LegalSection(
                  heading: 'Presizyon lis ak transparans',
                  paragraphs: <String>[
                    'Lis yo dwe dekri pwodwi oswa sèvis la jan li ye a, avèk pri ki klè, kondisyon enpòtan, frè, limit, ak tout kondisyon ki kapab afekte desizyon kliyan an.',
                    'Ou pa dwe kache enfomasyon enpòtan, itilize tit twonpe, oswa prezante foto ak deskripsyon ki pa koresponn ak sa kliyan an ap resevwa.',
                  ],
                ),
                LegalSection(
                  heading: 'Kontni entèdi ak restriksyon',
                  paragraphs: <String>[
                    'Ou pa ka poste atik oswa sèvis ki ilegal, danjere, kontrefè, vyolan, oswa ki vyole dwa lot moun. CaribTap ka retire kontni ki vyole lalwa oswa règ platfom nan san avètisman.',
                  ],
                  bulletPoints: <String>[
                    'Atik entèdi pa lalwa oswa pa règleman lokal',
                    'Pwodwi kontrefè oswa kontni ki vyole mak/dwa otè',
                    'Kontni twonpe, pònografik, rayisab, oswa ankouraje abi',
                    'Anons ki ankouraje fwod oswa manipile itilizate yo',
                  ],
                ),
                LegalSection(
                  heading: 'Responsablite vandè ak founise sèvis',
                  paragraphs: <String>[
                    'Moun ki poste lis yo responsab pou disponiblite, livrezon, kalite sèvis, kondisyon anilasyon, konfomite legal, taks, lisans, ak tout obligasyon ki konekte ak aktivite yo.',
                    'Ou dwe reponn kestyon kliyan yo ak bon fwa, mete lis yo ajou lè done yo chanje, epi retire ofri ki pa disponib ankò.',
                  ],
                ),
                LegalSection(
                  heading: 'Moderasyon ak aplikasyon',
                  paragraphs: <String>[
                    'CaribTap ka revize lis yo, mande koreksyon, limite vizibilite, oswa retire kontni ki pa konfom. Vyolasyon repete ka mennen nan sispansyon fonksyon, rediksyon rive, oswa fèmti kont.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'subscription_terms') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Tem abonnman',
              shortDescription:
                  'Règ plan peye, renouvèlman, anilasyon, ak aksè fonksyon premium yo.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Plan ak aktivasyon',
                  paragraphs: <String>[
                    'CaribTap ka ofri plizyè nivo abonnman ak avantaj diferan. Karakteristik, pri, ak limit chak plan ka varye selon peyi, aparèy, oswa pwomosyon aktif.',
                    'Aksè premium aktive apre peman valide atravè Apple App Store, Google Play, oswa lot chanèl faktirasyon ki otorize.',
                  ],
                ),
                LegalSection(
                  heading: 'Renouvèlman otomatik ak faktirasyon',
                  paragraphs: <String>[
                    'Sòf si ou anile anvan peryòd renouvèlman an, abonnman yo renouvle otomatikman dapre sik faktirasyon plan an. Founisè bòdwo a trete peman yo selon règleman li yo.',
                    'CaribTap ka resevwa estati tranzaksyon ak done limite pou jere aksè fonksyon yo, men li pa jere enfòmasyon kat ou dirèkteman lè acha a fèt atravè magazen app yo.',
                  ],
                ),
                LegalSection(
                  heading: 'Anilasyon ak chanjman plan',
                  paragraphs: <String>[
                    'Ou ka anile renouvèlman nan paramèt kont magazen ou itilize pou acha a. Anilasyon an anpeche pwochen renouvèlman men li pa efase aksè peryòd ki deja peye a, sof kote lalwa mande sa.',
                    'Chanjman nivo plan ka pran efè imedyatman oswa nan pwochen sik la selon règleman founise faktirasyon an.',
                  ],
                ),
                LegalSection(
                  heading: 'Ranbousman',
                  paragraphs: <String>[
                    'Sòf kote lalwa egzije sa, ranbousman yo jere pa Apple oswa Google dapre politik yo. CaribTap pa ka garanti rezilta demann ranbousman ki depann de desizyon founisè a.',
                  ],
                ),
                LegalSection(
                  heading: 'Abi abonnman',
                  paragraphs: <String>[
                    'CaribTap ka limite oswa revoke avantaj abonnman an si gen fwod, kontoune sistèm, pataj aksè san otorizasyon, oswa itilizasyon ki vyole politik platfom nan.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'trust_safety_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Politica de confianza y seguridad',
              shortDescription:
                  'Normas para la prevencion de fraude, reportes, verificacion y cumplimiento en CaribTap.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Principios de seguridad de la plataforma',
                  paragraphs: <String>[
                    'CaribTap trabaja para mantener un mercado confiable reduciendo el fraude, eliminando contenido dañino, fomentando interacciones transparentes y respondiendo a preocupaciones de seguridad creibles.',
                    'Ningun mercado en linea puede eliminar todo riesgo. Los usuarios deben actuar con cautela y usar su propio criterio al comunicarse, pagar, reservar o reunirse con otras personas.',
                  ],
                ),
                LegalSection(
                  heading: 'Prevencion de estafas y actividad sospechosa',
                  paragraphs: <String>[
                    'CaribTap puede monitorear señales asociadas con comportamiento sospechoso, incluida actividad inusual de cuentas, listados engañosos, quejas repetidas, comprobantes de pago falsificados, intentos de suplantacion o patrones consistentes con fraude o abuso.',
                    'Podemos limitar la visibilidad, solicitar informacion adicional, pausar funciones o limitar el acceso a la cuenta mientras se revisan las preocupaciones.',
                  ],
                ),
                LegalSection(
                  heading: 'Solicitudes de verificacion',
                  paragraphs: <String>[
                    'CaribTap puede solicitar a usuarios o negocios informacion o documentos de respaldo para verificar identidad, autoridad, propiedad, legitimidad del negocio o exactitud del listado. No cooperar con una solicitud razonable de verificacion puede resultar en acceso reducido, eliminacion de contenido o accion sobre la cuenta.',
                  ],
                ),
                LegalSection(
                  heading: 'Reporte de problemas',
                  paragraphs: <String>[
                    'Los usuarios deben reportar sospechas de fraude, estafas, comportamiento abusivo, listados inseguros, reseñas falsas o violaciones de politicas mediante las herramientas disponibles en la app o por canales de soporte.',
                    'Los reportes deben hacerse de buena fe e incluir detalles precisos cuando sea posible. Los reportes falsos o maliciosos pueden, por si mismos, violar las reglas de la plataforma.',
                  ],
                ),
                LegalSection(
                  heading: 'Recomendaciones de seguridad para usuarios',
                  paragraphs: <String>[
                    'Los usuarios deben verificar de forma independiente los detalles importantes antes de enviar dinero, compartir informacion sensible o entrar en un acuerdo de alquiler, reserva o servicio.',
                  ],
                  bulletPoints: <String>[
                    'Revisa cuidadosamente el listado, el perfil y el historial de chat',
                    'Confirma por escrito fechas, ubicacion, precios y condiciones de cancelacion',
                    'Ten precaucion con solicitudes de pago urgentes o presion fuera de la plataforma',
                    'Conserva registros de recibos, mensajes, cotizaciones, facturas y comprobantes de pago',
                  ],
                ),
                LegalSection(
                  heading: 'Acciones de cumplimiento',
                  paragraphs: <String>[
                    'Cuando corresponda, CaribTap puede emitir advertencias, rechazar anuncios, eliminar listados, reducir alcance, suspender mensajeria, limitar transacciones, restringir suscripciones o terminar cuentas. Tambien podemos conservar informacion para investigaciones o remitir asuntos a autoridades relevantes cuando corresponda.',
                  ],
                ),
              ],
            ),
          );
        }
        return _normalizeOverride(_LocalizedLegalDocumentOverride(
          title: {
            'privacy_policy': 'Politica de privacidad',
            'terms_of_service': 'Terminos del servicio',
            'marketplace_listing_policy': 'Politica del mercado y de listados',
            'subscription_terms': 'Terminos de suscripcion',
            'trust_safety_policy': 'Politica de confianza y seguridad',
            'transaction_dispute_policy':
                'Politica de transacciones y disputas',
            'ad_terms_conditions': 'Terminos y condiciones de anuncios',
          }[doc.id],
        ));
      case 'fr':
        if (doc.id == 'privacy_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Politique de confidentialite',
              shortDescription:
                  'Comment CaribTap collecte, utilise, partage et stocke les informations des utilisateurs.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Portee',
                  paragraphs: <String>[
                    'Cette Politique de confidentialite explique comment CaribTap collecte, utilise, divulgue et protege les informations lorsque vous utilisez l\'application CaribTap, le site web, les outils de messagerie, les annonces, les offres, la location, la reservation, l\'abonnement et les fonctionnalites de compte.',
                    'En creant un compte, en parcourant des annonces, en publiant du contenu ou en utilisant CaribTap d\'une autre maniere, vous reconnaissez que vos informations seront traitees comme decrit dans cette politique.',
                  ],
                ),
                LegalSection(
                  heading: 'Informations que nous collectons',
                  paragraphs: <String>[
                    'Nous collectons les informations que vous fournissez directement, y compris votre nom, adresse e-mail, numero de telephone, details de profil, preferences de compte, messages d\'assistance, informations d\'annonce, details de reservation, informations de devis et de facture, televersements de preuve de paiement, details d\'entreprise, informations de marque et parametres de collaboration ou d\'acces equipe.',
                    'Nous collectons egalement le contenu genere par les utilisateurs, tel que les descriptions d\'annonces, les prix, les photos, les videos, les documents, les avis, les messages, les creatives publicitaires, les parametres de disponibilite, les informations de location et les autres contenus que vous televersez ou soumettez via la plateforme.',
                    'Selon les autorisations de votre appareil et votre utilisation du service, nous pouvons collecter des informations de localisation approximatives ou precises pour prendre en charge la pertinence de recherche, les fonctionnalites de carte, la decouverte a proximite et les experiences de marche localisees.',
                  ],
                  bulletPoints: <String>[
                    'Inscription au compte et informations de profil',
                    'Contenu des annonces, locations, reservations, offres et mini-boutiques',
                    'Messages, demandes d\'assistance et preferences de notifications',
                    'Identifiants d\'appareil, journaux de plantage, analyses d\'usage et diagnostics de performance',
                    'Metadonnees de transaction fournies par Apple, Google ou des services integres',
                  ],
                ),
                LegalSection(
                  heading: 'Comment nous utilisons les informations',
                  paragraphs: <String>[
                    'CaribTap utilise les informations collecte es pour exploiter la place de marche, afficher des annonces et des publicites, alimenter les fonctions de recherche et de recommandation, traiter les reservations et les acces d\'abonnement, prendre en charge les locations et les flux documentaires, detecter les abus, personnaliser le contenu et ameliorer la fiabilite et la securite.',
                    'Nous pouvons egalement utiliser les informations pour communiquer avec vous au sujet de l\'activite du compte, des changements de politique, des alertes de securite, des annonces de service, du statut d\'abonnement, des decisions de moderation, des demandes d\'assistance ou des mises a jour de fonctionnalites pertinentes pour votre utilisation de l\'application.',
                  ],
                ),
                LegalSection(
                  heading: 'Paiements et abonnements',
                  paragraphs: <String>[
                    'La facturation des abonnements et certaines transactions d\'achat integree sont traitees par l\'Apple App Store ou Google Play, selon votre appareil et votre flux d\'achat. CaribTap ne stocke pas votre numero complet de carte de paiement lorsque la facturation est geree par Apple ou Google.',
                    'Nous pouvons recevoir des informations de transaction limitees des fournisseurs de facturation de plateforme, telles que le statut d\'achat, le niveau de plan, les dates de renouvellement, le pays et les identifiants de transaction, afin d\'activer des fonctionnalites, gerer les droits d\'acces et fournir l\'assistance.',
                  ],
                ),
                LegalSection(
                  heading: 'Partage et divulgation',
                  paragraphs: <String>[
                    'Nous pouvons partager des informations avec des prestataires de services qui nous aident a heberger l\'application, envoyer des notifications, stocker du contenu, fournir des analyses, moderer le contenu ou soutenir le service client. Nous pouvons egalement divulguer des informations lorsque la loi, une ordonnance judiciaire ou une reglementation l\'exige, ou pour proteger les droits, la securite et l\'integrite de CaribTap, de nos utilisateurs ou du public.',
                    'Le contenu que vous choisissez de publier, comme les annonces, avis, pages publiques de marque, publicites, details commerciaux ou documents partages destines aux clients, peut etre visible pour d\'autres utilisateurs ou destinataires selon les autorisations et fonctionnalites impliquees.',
                  ],
                ),
                LegalSection(
                  heading: 'Conservation des donnees et securite',
                  paragraphs: <String>[
                    'Nous conservons les informations aussi longtemps que raisonnablement necessaire pour fournir le service, respecter les obligations legales, resoudre des litiges, faire appliquer les accords, tenir des registres et soutenir la prevention de la fraude ou les besoins d\'audit.',
                    'CaribTap applique des mesures administratives, techniques et organisationnelles raisonnables pour proteger les informations, mais aucun systeme ne peut garantir une securite absolue. Vous etes responsable de la confidentialite de vos identifiants de connexion et des activites effectuees sous votre compte.',
                  ],
                ),
                LegalSection(
                  heading: 'Vos choix',
                  paragraphs: <String>[
                    'Vous pouvez mettre a jour certains details de compte dans l\'application, gerer les autorisations via les reglages de votre appareil et controler certaines notifications et parametres de visibilite dans votre profil ou vos outils d\'annonce.',
                    'Si vous souhaitez demander la suppression de votre compte ou de vos informations personnelles, contactez l\'assistance CaribTap via l\'application ou nos canaux d\'assistance designes. Nous pouvons conserver certains enregistrements lorsque cela est necessaire pour la conformite legale, la prevention de la fraude, la gestion des litiges ou des objectifs commerciaux legitimes.',
                  ],
                  bulletPoints: <String>[
                    'Consulter et mettre a jour les informations de profil',
                    'Gerer les autorisations de localisation, camera et notifications sur votre appareil',
                    'Demander la suppression du compte ou des donnees via l\'assistance',
                  ],
                ),
                LegalSection(
                  heading: 'Contact assistance et mises a jour',
                  paragraphs: <String>[
                    'Si vous avez des questions, preoccupations ou demandes sur la confidentialite, contactez l\'assistance CaribTap en utilisant l\'assistance integree ou les methodes de contact mises a disposition par la plateforme.',
                    'CaribTap peut mettre a jour cette Politique de confidentialite de temps a autre. L\'utilisation continue de la plateforme apres l\'entree en vigueur d\'une mise a jour constitue l\'acceptation de la politique revisee.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'terms_of_service') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Conditions d\'utilisation',
              shortDescription:
                  'Les principales conditions qui regissent l\'acces a CaribTap et l\'utilisation de la plateforme.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Acceptation des conditions',
                  paragraphs: <String>[
                    'Ces Conditions d\'utilisation regissent votre usage de CaribTap. En accedant a la plateforme ou en l\'utilisant, vous acceptez d\'etre lie par ces conditions ainsi que par toute politique supplementaire qui y est referencee.',
                    'Si vous n\'acceptez pas ces conditions, vous ne devez pas acceder a CaribTap ni l\'utiliser.',
                  ],
                ),
                LegalSection(
                  heading: 'Role de la plateforme',
                  paragraphs: <String>[
                    'CaribTap est une plateforme de marche et de decouverte qui permet aux utilisateurs, entreprises, prestataires de services, annonceurs, operateurs de location et acheteurs de creer des profils, publier des annonces, echanger des messages, recevoir des demandes, gerer des offres et coordonner des transactions. Sauf indication explicite contraire de CaribTap, CaribTap n\'est pas vendeur, bailleur, sequestre, processeur de paiement, courtier, assureur ni garant des transactions entre utilisateurs.',
                    'Les utilisateurs sont responsables de l\'evaluation des annonces, de la communication avec les parties concernees, de la verification des details et de la decision de poursuivre ou non une transaction ou une interaction.',
                  ],
                ),
                LegalSection(
                  heading: 'Comptes et eligibilite',
                  paragraphs: <String>[
                    'Vous devez fournir des informations exactes lors de la creation ou de la gestion de votre compte. Vous etes responsable de toutes les activites effectuees via votre compte et de la securite de vos identifiants de connexion.',
                    'CaribTap peut suspendre, restreindre ou resilier les comptes contenant de fausses informations, utilises en violation des politiques de la plateforme, ou creant un risque de securite, legal ou operationnel.',
                  ],
                ),
                LegalSection(
                  heading: 'Annonces, contenu et exactitude',
                  paragraphs: <String>[
                    'Vous etes seul responsable de la legalite, de l\'exactitude, de l\'exhaustivite et de la propriete du contenu que vous publiez sur CaribTap, y compris les annonces, photos, videos, descriptions, prix, disponibilites, promotions, conditions de location, informations de reservation, televersements de preuve de paiement et autres contenus generes par l\'utilisateur.',
                    'Vous devez disposer des droits, permissions et autorite necessaires pour publier tout contenu et proposer tout produit, service, location, reservation ou promotion que vous publiez.',
                  ],
                ),
                LegalSection(
                  heading: 'Transactions entre utilisateurs',
                  paragraphs: <String>[
                    'Les transactions, reservations, locations, prestations de services et achats sont principalement conclus entre utilisateurs. CaribTap ne garantit ni l\'execution, ni la livraison, ni la qualite, ni la legalite, ni le paiement, ni les remboursements, ni la satisfaction, sauf si un processus explicite controle par la plateforme l\'indique autrement.',
                    'Vous acceptez etre responsable de la resolution des problemes avec les contreparties, de la tenue de vos propres registres commerciaux et du respect de toutes les lois, taxes, licences, autorisations et obligations applicables a votre activite.',
                  ],
                ),
                LegalSection(
                  heading: 'Utilisation interdite',
                  paragraphs: <String>[
                    'Vous ne pouvez pas utiliser CaribTap pour publier du contenu illegal, porter atteinte a des droits de propriete intellectuelle, usurper l\'identite d\'autrui, frauder les utilisateurs, contourner les abonnements ou la moderation, diffuser des malwares, manipuler les avis, extraire les donnees de la plateforme sans autorisation ou perturber le service.',
                  ],
                  bulletPoints: <String>[
                    'Fraude, arnaques ou conduite trompeuse',
                    'Harcèlement, menaces, discours haineux ou contenu abusif',
                    'Produits contrefaits, articles interdits ou services illegaux',
                    'Collecte non autorisee de donnees utilisateur ou spam commercial',
                  ],
                ),
                LegalSection(
                  heading: 'Application et resiliation',
                  paragraphs: <String>[
                    'CaribTap peut enqueter sur des violations, supprimer du contenu, limiter la visibilite, emettre des avertissements, suspendre des fonctionnalites, rejeter des publicites, suspendre des abonnements ou resilier l\'acces a sa discretion lorsque cela est necessaire pour proteger les utilisateurs et la plateforme.',
                    'La suspension ou la resiliation n\'annule pas les obligations que vous avez contractees avant cette mesure, y compris celles liees aux litiges, frais, abus ou enquêtes.',
                  ],
                ),
                LegalSection(
                  heading: 'Limitation de responsabilite',
                  paragraphs: <String>[
                    'Dans toute la mesure permise par la loi, CaribTap n\'est pas responsable des dommages indirects, accessoires, consecutifs, speciaux, exemplaires ou punitifs, ni de la perte de profits, de la perte d\'activite, de la perte d\'opportunites, d\'atteinte a la reputation, de perte de donnees ou de litiges decoulant de la conduite des utilisateurs, des annonces, des publicites, des locations, des reservations ou des transactions.',
                    'CaribTap fournit la plateforme telle quelle et selon disponibilite, et ne garantit pas un acces ininterrompu, un fonctionnement sans erreur ni aucun resultat commercial specifique.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'marketplace_listing_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Politique de la place de marche et des annonces',
              shortDescription:
                  'Regles pour creer des annonces exactes, fixer des prix de facon responsable et maintenir la qualite de la place de marche.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Exactitude des annonces',
                  paragraphs: <String>[
                    'Toutes les annonces sur CaribTap doivent decrire avec exactitude l\'article, le service, la location, l\'evenement, l\'offre ou la proposition promue. Les titres, photos, prix, disponibilites, categories, commodites et details d\'etat ne doivent pas etre trompeurs ni incomplets de maniere significative.',
                    'Les utilisateurs doivent mettre a jour rapidement leurs annonces lorsque des details essentiels changent, y compris les prix, la disponibilite, les coordonnees, l\'etendue du service, les conditions de location ou le statut de l\'entreprise.',
                  ],
                ),
                LegalSection(
                  heading: 'Photos, medias et declarations',
                  paragraphs: <String>[
                    'Les images, videos et medias ameli ores par IA utilises sur CaribTap doivent representer l\'offre annoncee de maniere juste et non trompeuse. Les outils d\'edition peuvent ameliorer la qualite, mais les medias ne doivent pas deformer de facon importante la taille, l\'etat, les caracteristiques, les livrables ou les resultats.',
                    'Les declarations sur les produits, services, promotions, qualite ou resultats doivent etre veridiques et verifiables.',
                  ],
                ),
                LegalSection(
                  heading: 'Articles et services interdits',
                  paragraphs: <String>[
                    'Les annonces ne peuvent pas promouvoir des biens ou services illegaux, dangereux, contrefaits ou autrement interdits. CaribTap peut supprimer ou restreindre le contenu qui cree des risques legaux, de securite, de reputation ou de confiance.',
                  ],
                  bulletPoints: <String>[
                    'Biens illegaux ou articles reglementes interdits par la loi',
                    'Biens contrefaits ou violations de propriete intellectuelle',
                    'Offres financieres frauduleuses, usurpation d\'identite ou schemas trompeurs',
                    'Services necessitant des licences ou autorisations que le prestataire ne detient pas',
                  ],
                ),
                LegalSection(
                  heading: 'Prix et disponibilite',
                  paragraphs: <String>[
                    'Les prix doivent etre veridiques, raisonnablement clairs et non manipules intentionnellement pour attirer les utilisateurs sous de faux pretextes. Toute condition importante, frais de livraison, frais supplementaires, minimums, depots ou limitations de reservation doit etre indiquee avant qu\'un utilisateur ne s\'engage.',
                    'Si le stock, les dates, les unites ou la disponibilite sont limites, les annonces doivent le refleter avec precision.',
                  ],
                ),
                LegalSection(
                  heading: 'Locations et reservations',
                  paragraphs: <String>[
                    'Les annonces de location et de reservation doivent communiquer clairement les regles d\'usage, les fenetres de disponibilite, les attentes de remboursement ou d\'annulation, les details d\'arrivee ou d\'execution, ainsi que tout document ou depot requis. Les prestataires restent responsables d\'honorer les accords confirmes, sauf indication contraire conforme a la loi.',
                  ],
                ),
                LegalSection(
                  heading: 'Avis et integrite',
                  paragraphs: <String>[
                    'Les utilisateurs ne peuvent pas acheter, vendre, fabriquer, echanger ou manipuler des avis, notes, favoris ou signaux d\'engagement sur CaribTap. Le contenu visant a gonfler artificiellement la performance des annonces ou a induire les utilisateurs en erreur sur la credibilite est interdit.',
                  ],
                ),
                LegalSection(
                  heading: 'Suppression et visibilite',
                  paragraphs: <String>[
                    'CaribTap peut modifier, limiter, retirer, retrograder ou supprimer des annonces qui violent les politiques, generent des plaintes repetees, contiennent des informations obsoletes ou nuisent a la confiance et a la securite sur la plateforme.',
                    'La visibilite, le classement et le positionnement dans la recherche peuvent evoluer avec le temps et ne sont pas garantis.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'subscription_terms') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Conditions d\'abonnement',
              shortDescription:
                  'Conditions pour les plans Professional et Premium, la facturation, les renouvellements et l\'acces aux fonctionnalites.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Plans d\'abonnement',
                  paragraphs: <String>[
                    'CaribTap peut proposer des niveaux d\'abonnement, y compris Professional et Premium, qui debloquent des outils ameliores et des fonctionnalites de visibilite. Les avantages disponibles peuvent inclure des annonces supplementaires, des outils de reservation, des analyses, des controles de messagerie directe, des quotas de publication d\'annonces, des outils business ou d\'autres capacites premium indiquees dans l\'application au moment de l\'achat.',
                  ],
                ),
                LegalSection(
                  heading: 'Fournisseurs de facturation',
                  paragraphs: <String>[
                    'Les abonnements achetes dans l\'application sont generalement factures via Apple App Store ou Google Play. Votre relation de facturation pour ces achats est regie par les conditions du store applicable, en plus des politiques de CaribTap.',
                    'CaribTap peut recevoir des informations de statut et de renouvellement du fournisseur de facturation afin d\'activer et de maintenir l\'acces au plan.',
                  ],
                ),
                LegalSection(
                  heading: 'Renouvellement automatique',
                  paragraphs: <String>[
                    'Sauf annulation via le fournisseur de facturation applicable, les abonnements se renouvellent automatiquement a la fin de chaque cycle de facturation. Le calendrier de renouvellement, les taxes et les methodes de facturation sont geres par Apple ou Google lorsque ces fournisseurs traitent l\'achat.',
                  ],
                ),
                LegalSection(
                  heading: 'Gestion et annulation',
                  paragraphs: <String>[
                    'Vous etes responsable de la gestion, de la modification ou de l\'annulation de votre abonnement via l\'Apple App Store, Google Play ou toute autre interface de facturation utilisee pour votre achat. Supprimer l\'application ou supprimer un compte n\'annule pas automatiquement un abonnement actif.',
                  ],
                ),
                LegalSection(
                  heading: 'Remboursements',
                  paragraphs: <String>[
                    'Lorsque Apple ou Google a traite l\'achat, les demandes de remboursement sont gerees par ce fournisseur selon ses propres politiques. CaribTap ne peut pas annuler les decisions de remboursement de l\'App Store ou de Google Play pour les achats qu\'ils administrent.',
                  ],
                ),
                LegalSection(
                  heading: 'Acces aux fonctionnalites et expiration',
                  paragraphs: <String>[
                    'Les fonctionnalites basees sur l\'abonnement sont disponibles uniquement tant que votre plan reste actif et en regle. Si un abonnement expire, est annule, rembourse ou devient invalide, l\'acces aux fonctionnalites premium peut etre reduit ou supprime.',
                    'Les droits du plan, quotas inclus et limites de fonctionnalites sont reinitialises ou renouveles selon les conditions du cycle d\'abonnement actif pour ce plan.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'transaction_dispute_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Politique des transactions et litiges',
              shortDescription:
                  'Comment CaribTap traite les paiements utilisateur, preuves de paiement, annulations, locations et litiges.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Role de CaribTap',
                  paragraphs: <String>[
                    'Sauf indication expresse contraire de CaribTap pour une fonctionnalite specifique, CaribTap n\'est pas un service de sequestre, un agent ou une partie aux transactions entre utilisateurs. Acheteurs, locataires, vendeurs, hotes, prestataires et entreprises restent responsables de leurs propres accords, communications et decisions de paiement.',
                  ],
                ),
                LegalSection(
                  heading: 'Paiements et responsabilite de paiement',
                  paragraphs: <String>[
                    'Les utilisateurs sont responsables du choix des methodes de paiement, de la confirmation des coordonnees du destinataire et de la conservation des preuves de ce qui a ete convenu. CaribTap ne garantit pas qu\'un paiement est valide, recu, autorise ou utilise a son objectif prevu du seul fait que des informations ont ete partagees sur la plateforme.',
                  ],
                ),
                LegalSection(
                  heading: 'Preuve de paiement',
                  paragraphs: <String>[
                    'Les fonctionnalites de preuve de paiement sur CaribTap sont des outils de communication et de support destines a aider les utilisateurs a partager des preuves pertinentes a une transaction. Elles ne constituent pas une certification par CaribTap qu\'un paiement est authentique, definitif, compense ou irreversible.',
                    'Les utilisateurs doivent verifier de maniere independante les preuves de paiement avant de remettre des biens, des cles, un acces, des services ou des remboursements.',
                  ],
                ),
                LegalSection(
                  heading: 'Locations, reservations et execution',
                  paragraphs: <String>[
                    'Les locations, reservations, check-ins, annulations, reprogrammations, depots et conditions d\'execution sont geres par les utilisateurs concernes, sauf si CaribTap fournit un flux explicitement controle par la plateforme indiquant le contraire. Prestataires et clients sont tenus de communiquer clairement et de conserver des registres precis.',
                  ],
                ),
                LegalSection(
                  heading: 'Annulations et remboursements',
                  paragraphs: <String>[
                    'Les resultats des annulations et remboursements dependent de l\'accord entre les utilisateurs concernes, du droit applicable et de toute condition clairement divulguee. CaribTap peut examiner des plaintes ou justificatifs, mais ne garantit pas qu\'une partie sera remboursee ou indemnisee.',
                  ],
                ),
                LegalSection(
                  heading: 'Litiges et declarations frauduleuses',
                  paragraphs: <String>[
                    'Les utilisateurs ne doivent pas soumettre de recus falsifies, de fausses preuves de paiement, de declarations de litige trompeuses, de demandes de remboursement fabriquees ou d\'autres contenus trompeurs. Les declarations frauduleuses peuvent entrainer des restrictions de compte, un retrait de la plateforme ou un signalement aux autorites ou aux fournisseurs de paiement lorsque cela est approprie.',
                    'CaribTap peut examiner les messages, metadonnees de transaction, documents televerses, horodatages et enregistrements de plateforme associes lors des enquetes sur les litiges ou signalements d\'abus.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'ad_terms_conditions') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Conditions des annonces',
              shortDescription:
                  'Regles pour les publications d\'offres et d\'annonces incluses avec les abonnements CaribTap eligibles.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Eligibilite',
                  paragraphs: <String>[
                    'Seuls les utilisateurs ayant des abonnements CaribTap eligibles peuvent soumettre des annonces promotionnelles ou des placements d\'offres pour publication sur la plateforme. La disponibilite des annonces est determinee par le niveau d\'abonnement actif sur le compte au moment de la soumission et de la revision de l\'annonce.',
                  ],
                ),
                LegalSection(
                  heading: 'Quota mensuel d\'annonces inclus',
                  paragraphs: <String>[
                    'Les annonces CaribTap ne sont pas achetees separement dans le modele actuel. A la place, des abonnements eligibles comme Professional et Premium peuvent inclure un nombre fixe de publications d\'annonces ou d\'offres dans chaque cycle mensuel d\'abonnement.',
                    'Le nombre d\'opportunites d\'annonces incluses depend du plan rattache au compte de l\'utilisateur. CaribTap peut mettre a jour les fonctionnalites de plan et les allocations de quota au fil du temps.',
                  ],
                ),
                LegalSection(
                  heading: 'Utilisation et reinitialisation du quota',
                  paragraphs: <String>[
                    'Un emplacement inclus est consomme lorsqu\'une annonce est approuvee et publiee sur la plateforme. Les brouillons, soumissions incompletes et annonces non approuvees ne consomment pas de quota, sauf indication explicite contraire dans l\'application.',
                    'Le quota inclus est reinitialise selon le cycle d\'abonnement actif. Les quotas non utilises ne sont pas reportes au mois suivant et n\'ont pas de valeur cumulable.',
                  ],
                ),
                LegalSection(
                  heading: 'Annonces rejetees ou supprimees',
                  paragraphs: <String>[
                    'Si une annonce est rejetee avant publication parce qu\'elle ne respecte pas les politiques CaribTap, l\'emplacement associe n\'est generalement pas consomme ou peut etre restaure selon le cas. CaribTap conserve l\'entiere discretion pour determiner si une soumission rejetee est eligible a la restauration de quota.',
                    'Si une annonce a ete approuvee et publiee, sa suppression anticipee ou une demande de retrait ne restaure pas le quota utilise pour ce cycle de facturation.',
                  ],
                ),
                LegalSection(
                  heading: 'Exigences de contenu des annonces',
                  paragraphs: <String>[
                    'Toutes les annonces doivent etre exactes, legales et conformes aux normes de marche, de confiance et de securite de CaribTap. Les annonceurs sont responsables de tous les textes, images, videos, declarations de prix, offres et contenus promotionnels figurant dans une annonce.',
                  ],
                  bulletPoints: <String>[
                    'Aucun produit ou service illegal',
                    'Aucune declaration trompeuse, mensongere ou invérifiable',
                    'Aucun contenu offensant, abusif, discriminatoire ou dangereux',
                    'Aucune contrefacon, usurpation, arnaque ou offre frauduleuse',
                  ],
                ),
                LegalSection(
                  heading: 'Revision, approbation et visibilite',
                  paragraphs: <String>[
                    'Toutes les annonces sont soumises a revision avant publication. CaribTap peut approuver, rejeter, demander des modifications, suspendre, restreindre ou supprimer toute annonce a sa discretion pour proteger la confiance des utilisateurs, la conformite legale et l\'integrite de la plateforme.',
                    'CaribTap ne garantit aucun nombre specifique d\'impressions, clics, favoris, prospects, messages, reservations, conversions ou ventes provenant d\'un placement d\'annonce, sauf engagement ecrit explicite de la plateforme.',
                  ],
                ),
                LegalSection(
                  heading: 'Responsabilite de l\'annonceur',
                  paragraphs: <String>[
                    'Les annonceurs demeurent seuls responsables de s\'assurer qu\'ils disposent des droits et de l\'autorite necessaires pour utiliser toutes les marques, medias, marques deposees, offres et contenus promotionnels inclus dans leurs annonces. Les annonceurs sont egalement responsables du respect des offres, prix et declarations presentes aux utilisateurs.',
                  ],
                ),
                LegalSection(
                  heading:
                      'Pas de transfert, pas de remboursement, pas de valeur en especes',
                  paragraphs: <String>[
                    'Les quotas d\'annonces inclus avec un abonnement sont personnels au compte et non transferables. Ils ne peuvent pas etre echanges contre especes, credits, remboursements ou compensation, qu\'ils soient utilises ou non.',
                    'Etant donne que le modele actuel d\'annonce repose sur des quotas inclus dans les avantages d\'abonnement plutot que sur des frais d\'achat d\'annonce distincts, toute regle de non-remboursement ou de non-valeur en especes s\'applique au quota inclus lui-meme, et non a un paiement d\'annonce autonome.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'trust_safety_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Politique de confiance et de securite',
              shortDescription:
                  'Normes de prevention de la fraude, de signalement, de verification et d\'application sur CaribTap.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Principes de securite de la plateforme',
                  paragraphs: <String>[
                    'CaribTap s\'efforce de maintenir une place de marche fiable en reduisant la fraude, en supprimant les contenus nuisibles, en encourageant des interactions transparentes et en repondant aux preoccupations de securite credibles.',
                    'Aucune place de marche en ligne ne peut eliminer tous les risques. Les utilisateurs doivent faire preuve de prudence et utiliser leur propre jugement lorsqu\'ils communiquent, paient, reservent ou rencontrent d\'autres personnes.',
                  ],
                ),
                LegalSection(
                  heading: 'Prevention des arnaques et activite suspecte',
                  paragraphs: <String>[
                    'CaribTap peut surveiller les signaux associes a un comportement suspect, notamment une activite inhabituelle du compte, des annonces trompeuses, des plaintes repetees, des preuves de paiement falsifiees, des tentatives d\'usurpation d\'identite ou des schémas compatibles avec la fraude ou l\'abus.',
                    'Nous pouvons limiter la visibilite, demander des informations supplementaires, suspendre des fonctionnalites ou limiter l\'acces au compte pendant l\'examen des preoccupations.',
                  ],
                ),
                LegalSection(
                  heading: 'Demandes de verification',
                  paragraphs: <String>[
                    'CaribTap peut demander aux utilisateurs ou aux entreprises de fournir des informations ou des documents justificatifs pour verifier l\'identite, l\'autorite, la propriete, la legitimite de l\'entreprise ou l\'exactitude d\'une annonce. Le refus de cooperer a une demande raisonnable de verification peut entrainer une reduction d\'acces, la suppression de contenu ou une action sur le compte.',
                  ],
                ),
                LegalSection(
                  heading: 'Signalement des problemes',
                  paragraphs: <String>[
                    'Les utilisateurs doivent signaler les soupçons de fraude, d\'arnaques, de comportement abusif, d\'annonces dangereuses, de faux avis ou de violations de politique via les outils disponibles dans l\'application ou par les canaux d\'assistance.',
                    'Les signalements doivent etre faits de bonne foi et inclure des informations exactes lorsque possible. Les signalements faux ou malveillants peuvent eux-memes violer les regles de la plateforme.',
                  ],
                ),
                LegalSection(
                  heading: 'Recommandations de securite pour les utilisateurs',
                  paragraphs: <String>[
                    'Les utilisateurs doivent verifier de maniere independante les details importants avant d\'envoyer de l\'argent, de partager des informations sensibles ou de conclure un accord de location, de reservation ou de service.',
                  ],
                  bulletPoints: <String>[
                    'Examinez attentivement l\'annonce, le profil et l\'historique de conversation',
                    'Confirmez par ecrit les dates, le lieu, les prix et les conditions d\'annulation',
                    'Soyez prudent face aux demandes de paiement urgentes ou aux pressions hors plateforme',
                    'Conservez les justificatifs de recus, messages, devis, factures et preuves de paiement',
                  ],
                ),
                LegalSection(
                  heading: 'Mesures d\'application',
                  paragraphs: <String>[
                    'Lorsque cela est justifie, CaribTap peut emettre des avertissements, rejeter des annonces, supprimer des publications, reduire la portee, suspendre la messagerie, limiter les transactions, restreindre les abonnements ou resilier des comptes. Nous pouvons egalement conserver des informations pour des enquêtes ou transmettre certains dossiers aux autorites competentes lorsque cela est approprie.',
                  ],
                ),
              ],
            ),
          );
        }
        return _normalizeOverride(_LocalizedLegalDocumentOverride(
          title: {
            'privacy_policy': 'Politique de confidentialite',
            'terms_of_service': 'Conditions d\'utilisation',
            'marketplace_listing_policy':
                'Politique de la place de marche et des annonces',
            'subscription_terms': 'Conditions d\'abonnement',
            'trust_safety_policy': 'Politique de confiance et de securite',
            'transaction_dispute_policy':
                'Politique des transactions et litiges',
            'ad_terms_conditions': 'Conditions des annonces',
          }[doc.id],
        ));
      case 'ht':
        if (doc.id == 'privacy_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Politik konfidansyalite',
              shortDescription:
                  'Kijan CaribTap ranmase, itilize, pataje, epi estoke enfomasyon itilizate yo.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Sijesyon ak aplikasyon',
                  paragraphs: <String>[
                    'Politik Konfidansyalite sa a esplike kijan CaribTap ranmase, itilize, pataje, epi pwoteje enfomasyon pandan ou ap itilize app CaribTap la, sit web la, zouti mesajri, lis yo, promo yo, lokasyon yo, rezervasyon yo, abonnman yo, ak fonksyon kont yo.',
                    'Lè ou kreye yon kont, navige lis yo, pibliye kontni, oswa itilize CaribTap nenpòt lot fason, ou rekonet enfomasyon ou ap trete dapre politik sa a.',
                  ],
                ),
                LegalSection(
                  heading: 'Enfomasyon nou ranmase',
                  paragraphs: <String>[
                    'Nou ranmase enfomasyon ou bay direkteman, tankou non ou, imel ou, nimewo telefon ou, detay pwofil, preferans kont, mesaj sipò, enfomasyon lis, detay rezervasyon, enfomasyon devis ak fakti, telechajman prèv peman, detay biznis, enfomasyon mak, ak konfigirasyon kolaborasyon oswa aksè ekip.',
                    'Nou ranmase tou kontni itilizate yo kreye, tankou deskripsyon lis, pri, foto, videyo, dokiman, revizyon, mesaj, kontni piblisite, paramet disponiblite, enfomasyon lokasyon, ak lot materyel ou telechaje oswa soumet sou platfom nan.',
                    'Selon pèmisyon aparèy ou ak fason ou itilize sèvis la, nou ka ranmase enfomasyon kote a ki presi oswa apepre pou sipote rezilta rechèch yo, fonksyon kat, dekouvèt ki toupre, ak eksperyans mache lokalize.',
                  ],
                  bulletPoints: <String>[
                    'Enskripsyon kont ak enfomasyon pwofil',
                    'Kontni lis, lokasyon, rezervasyon, promo, ak mini magazen',
                    'Mesaj, demann sipò, ak preferans notifikasyon',
                    'Idantifyan aparèy, log erè, analiz itilizasyon, ak dyagnostik pèfomans',
                    'Metadone tranzaksyon soti nan Apple, Google, oswa sèvis entegre',
                  ],
                ),
                LegalSection(
                  heading: 'Kijan nou itilize enfomasyon',
                  paragraphs: <String>[
                    'CaribTap itilize enfomasyon nou ranmase pou opere mache a, montre lis ak piblisite, alimante rechèch ak rekòmandasyon, trete rezervasyon ak aksè abonnman, sipote lokasyon ak workflows dokiman, detekte abi, pèsonalize kontni, epi amelyore fyab ak sekirite.',
                    'Nou ka itilize enfomasyon tou pou kominike avèk ou sou aktivite kont, chanjman politik, alèt sekirite, anons sèvis, estati abonnman, desizyon moderasyon, sijè sipò, oswa mizajou fonksyon ki gen rapò ak itilizasyon app la.',
                  ],
                ),
                LegalSection(
                  heading: 'Peman ak abonnman',
                  paragraphs: <String>[
                    'Faktirasyon abonnman ak kèk acha anndan app la trete pa Apple App Store oswa Google Play, selon aparèy ou ak pwosesis acha a. CaribTap pa estoke nimewo kat konplè ou lè Apple oswa Google ap jere faktirasyon an.',
                    'Nou ka resevwa enfomasyon tranzaksyon limite nan men founise faktirasyon yo, tankou estati acha, nivo plan, dat renouvelman, peyi, ak id tranzaksyon, pou aktive fonksyon, jere aksè dwa, epi bay sipò.',
                  ],
                ),
                LegalSection(
                  heading: 'Pataj ak divilgasyon',
                  paragraphs: <String>[
                    'Nou ka pataje enfomasyon ak founise sèvis ki ede nou host app la, voye notifikasyon, estoke kontni, bay analytics, modere kontni, oswa sipote sèvis kliyan. Nou ka divilge enfomasyon tou lè lalwa, lòd tribinal, oswa regilasyon egzije sa, oswa pou pwoteje dwa, sekirite, ak entegrite CaribTap, itilizate nou yo, oswa piblik la.',
                    'Kontni ou chwazi pibliye, tankou lis, revizyon, paj piblik mak, piblisite, detay biznis, oswa dokiman pataje pou kliyan, ka vizib pou lot itilizate oswa reseptè selon pèmisyon ak fonksyon ki enplike.',
                  ],
                ),
                LegalSection(
                  heading: 'Retansyon done ak sekirite',
                  paragraphs: <String>[
                    'Nou konsève enfomasyon pandan tan ki rezonabman nesesè pou bay sèvis la, respekte obligasyon legal, rezoud konfli, fè respekte akò, kenbe dosye, epi sipote prevansyon fwod oswa bezwen odit.',
                    'CaribTap itilize mezi administratif, teknik, ak òganizasyonèl rezonab pou pwoteje enfomasyon, men pa gen sistèm ki ka garanti sekirite absoli. Ou responsab pou kenbe kredansyèl koneksyon ou konfidansyèl ak pou aktivite ki fèt sou kont ou.',
                  ],
                ),
                LegalSection(
                  heading: 'Opsyon ou yo',
                  paragraphs: <String>[
                    'Ou ka mete ajou kèk detay kont nan app la, jere pèmisyon yo nan paramet aparèy ou, epi kontwole kèk notifikasyon ak vizibilite nan pwofil ou oswa zouti lis yo.',
                    'Si ou vle mande efasman kont ou oswa enfomasyon pèsonèl ou, kontakte sipò CaribTap atravè app la oswa chanèl sipò ofisyel yo. Nou ka kenbe kèk dosye kote sa nesesè pou konfomite legal, prevansyon fwod, jesyon konfli, oswa objektif biznis lejitim.',
                  ],
                  bulletPoints: <String>[
                    'Revize epi mete ajou enfomasyon pwofil',
                    'Jere pèmisyon kote, kamera, ak notifikasyon sou aparèy ou',
                    'Mande efasman kont oswa done atravè sipò',
                  ],
                ),
                LegalSection(
                  heading: 'Kontak sipò ak mizajou',
                  paragraphs: <String>[
                    'Si ou gen kestyon, enkyetid, oswa demann sou konfidansyalite, kontakte sipò CaribTap ak zouti sipò anndan app la oswa metòd kontak platfom nan mete disponib.',
                    'CaribTap ka mete ajou Politik Konfidansyalite sa a detanzantan. Kontinye itilize platfom nan apre yon mizajou antre an vigè vle di ou aksepte politik la revize.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'terms_of_service') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Tem itilizasyon',
              shortDescription:
                  'Tem prensipal ki gouvène aksè ak itilizasyon CaribTap sou platfom nan.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Akseptasyon tem yo',
                  paragraphs: <String>[
                    'Tem Itilizasyon sa yo gouvène fason ou itilize CaribTap. Lè ou antre oswa itilize platfom nan, ou dakò ak tem sa yo ansanm ak nenpòt politik adisyonèl yo refere ladan yo.',
                    'Si ou pa dakò ak tem sa yo, ou pa dwe antre oswa itilize CaribTap.',
                  ],
                ),
                LegalSection(
                  heading: 'Wòl platfom nan',
                  paragraphs: <String>[
                    'CaribTap se yon platfom mache ak dekouvèt ki pèmèt itilizate yo, biznis yo, founise sèvis yo, piblisite yo, operatè lokasyon yo, ak achtè yo kreye pwofil, pibliye lis, echanje mesaj, resevwa kestyon, jere promo, epi kowòdone tranzaksyon. Sof kote CaribTap di sa klèman otreman, CaribTap pa vandè, pa lokatè, pa escrow, pa processeur peman, pa koutye, pa asirè, epi pa garanti tranzaksyon ant itilizate yo.',
                    'Itilizate yo responsab pou evalye lis yo, kominike ak lot pati yo, verifye detay yo, epi deside si yo pral kontinye ak yon tranzaksyon oswa angajman.',
                  ],
                ),
                LegalSection(
                  heading: 'Kont ak elijibilite',
                  paragraphs: <String>[
                    'Ou dwe bay enfomasyon ki egzat lè ou ap kreye oswa kenbe yon kont. Ou responsab pou tout aktivite ki fèt sou kont ou ak pou sekirite kredansyèl koneksyon ou.',
                    'CaribTap ka sispann, limite, oswa fèmen kont ki gen fo enfomasyon, ki itilize an vyolasyon politik platfom nan, oswa ki kreye risk sekirite, legal, oswa operasyonèl.',
                  ],
                ),
                LegalSection(
                  heading: 'Lis, kontni, ak presizyon',
                  paragraphs: <String>[
                    'Ou se sel moun ki responsab pou legalite, presizyon, konplè, ak pwopriyetè kontni ou pibliye sou CaribTap, tankou lis, foto, videyo, deskripsyon, pri, disponiblite, promo, tem lokasyon, enfomasyon rezèvasyon, prèv peman telechaje, ak lot kontni itilizate kreye.',
                    'Ou dwe gen dwa, pèmisyon, ak otorite nesesè pou pibliye tout kontni ak ofri nenpòt pwodwi, sèvis, lokasyon, rezèvasyon, oswa promo ou poste.',
                  ],
                ),
                LegalSection(
                  heading: 'Tranzaksyon ant itilizate yo',
                  paragraphs: <String>[
                    'Tranzaksyon, rezèvasyon, lokasyon, aranjman sèvis, ak acha fèt prensipalman ant itilizate yo. CaribTap pa garanti pèfomans, livrezon, kalite, legalite, peman, ranbousman, oswa satisfaksyon sof si gen yon pwosesis platfom ki kontwole sa klèman.',
                    'Ou dakò ou responsab pou rezoud pwoblèm ak lot pati yo, kenbe dosye biznis ou, epi respekte tout lwa, taks, lisans, pèmi, ak obligasyon ki aplikab a aktivite ou.',
                  ],
                ),
                LegalSection(
                  heading: 'Itilizasyon entèdi',
                  paragraphs: <String>[
                    'Ou pa ka itilize CaribTap pou pibliye kontni ilegal, vyole dwa pwopriyete entelektyèl, fè tèt ou pase pou lot moun, fwode itilizate yo, kontoune abonnman oswa moderasyon, distribye malveyan, manipile revizyon, rale done platfom nan san pèmisyon, oswa deranje sèvis la.',
                  ],
                  bulletPoints: <String>[
                    'Fwod, magouy, oswa konduit twonpe',
                    'Arasman, menas, diskou rayisab, oswa kontni abi',
                    'Machandiz kontrefè, atik entèdi, oswa sèvis ilegal',
                    'Ranmase done itilizate san otorizasyon oswa spam komèsyal',
                  ],
                ),
                LegalSection(
                  heading: 'Aplikasyon ak fèmti aksè',
                  paragraphs: <String>[
                    'CaribTap ka mennen ankèt sou vyolasyon, retire kontni, limite vizibilite, bay avètisman, mete fonksyon sou poz, rejte piblisite, sispann abonnman, oswa fèmen aksè a diskresyon li kote sa nesesè pou pwoteje itilizate yo ak platfom nan.',
                    'Sispansyon oswa fèmti pa retire obligasyon ou te genyen anvan mezi sa a, tankou obligasyon ki gen rapò ak konfli, frè, move itilizasyon, oswa ankèt.',
                  ],
                ),
                LegalSection(
                  heading: 'Limit responsabilite',
                  paragraphs: <String>[
                    'Nan limit lalwa pèmèt, CaribTap pa responsab pou domaj endirèk, aksidantèl, konsekansyèl, espesyal, egzanplè, oswa pinisyon, ni pou pèt pwofi, pèt biznis, pèt opòtinite, domaj repitasyon, pèt done, oswa konfli ki soti nan konduit itilizate, lis, piblisite, lokasyon, rezèvasyon, oswa tranzaksyon.',
                    'CaribTap bay platfom nan jan li ye a ak selon disponiblite, epi li pa garanti aksè san entèripsyon, operasyon san erè, oswa okenn rezilta biznis espesifik.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'trust_safety_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Politik konfyans ak sekirite',
              shortDescription:
                  'Nòm pou prevansyon fwod, rapò, verifikasyon ak aplikasyon sou CaribTap.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Prensip sekirite platfom nan',
                  paragraphs: <String>[
                    'CaribTap ap travay pou kenbe yon mache ki fyab lè li diminye fwod, retire kontni danjere, ankouraje entèraksyon transparan, epi reponn ak enkyetid sekirite ki kredib.',
                    'Pa gen okenn mache sou entènèt ki ka elimine tout risk. Itilizatè yo dwe pran prekosyon epi sèvi ak bon jijman yo lè y ap kominike, peye, rezève, oswa rankontre lòt moun.',
                  ],
                ),
                LegalSection(
                  heading: 'Prevansyon magouy ak aktivite sispèk',
                  paragraphs: <String>[
                    'CaribTap ka siveye siyal ki asosye ak konpòtman sispèk, tankou aktivite kont etranj, lis ki twonpe, plent repete, prèv peman fo, tantativ pou fè tèt ou pase pou lòt moun, oswa modèl ki montre fwod oswa abi.',
                    'Nou ka limite vizibilite, mande plis enfòmasyon, mete fonksyon sou poz, oswa limite aksè kont lan pandan enkyetid yo ap revize.',
                  ],
                ),
                LegalSection(
                  heading: 'Demann verifikasyon',
                  paragraphs: <String>[
                    'CaribTap ka mande itilizatè oswa biznis yo bay enfòmasyon oswa dokiman sipò pou verifye idantite, otorite, pwopriyetè, lejitimite biznis, oswa presizyon lis la. Refize kolabore ak yon demann verifikasyon ki rezonab ka mennen nan rediksyon aksè, retire kontni, oswa aksyon sou kont la.',
                  ],
                ),
                LegalSection(
                  heading: 'Rapòte pwoblèm',
                  paragraphs: <String>[
                    'Itilizatè yo ta dwe rapòte sispèk fwod, magouy, konpòtman abi, lis ki pa an sekirite, fo revizyon, oswa vyolasyon politik atravè zouti ki disponib nan app la oswa chanèl sipò yo.',
                    'Rapò yo dwe fèt ak bon fwa epi yo dwe gen detay egzak lè sa posib. Fo rapò oswa rapò ak move entansyon ka, pa yo menm, vyole règ platfom nan.',
                  ],
                ),
                LegalSection(
                  heading: 'Rekòmandasyon sekirite pou itilizatè yo',
                  paragraphs: <String>[
                    'Itilizatè yo dwe verifye detay enpòtan yo poukont yo anvan yo voye lajan, pataje enfòmasyon sansib, oswa antre nan yon aranjman lokasyon, rezèvasyon, oswa sèvis.',
                  ],
                  bulletPoints: <String>[
                    'Revize lis la, pwofil la, ak istwa chat la ak anpil atansyon',
                    'Konfime dat, kote, pri, ak kondisyon anilasyon yo alekri',
                    'Pran prekosyon ak demann peman ijan oswa presyon deyò platfom nan',
                    'Kenbe dosye resi, mesaj, devis, fakti, ak prèv peman',
                  ],
                ),
                LegalSection(
                  heading: 'Mezi aplikasyon',
                  paragraphs: <String>[
                    'Lè sa nesesè, CaribTap ka bay avètisman, rejte anons, retire lis, diminye rive, sispann mesajri, limite tranzaksyon, limite abonnman, oswa fèmen kont. Nou ka tou konsève enfòmasyon pou ankèt oswa voye dosye yo bay otorite ki konsène yo kote sa apwopriye.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'transaction_dispute_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Politik tranzaksyon ak konfli',
              shortDescription:
                  'Prensip pou dokimantasyon, rapò pwoblèm, ak rezolisyon konfli ant itilizate yo.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Dimansyon politik la',
                  paragraphs: <String>[
                    'Politik sa a esplike kijan itilizate yo dwe jere konfli ki soti nan lavant, sèvis, lokasyon, rezèvasyon, oswa lot tranzaksyon fasilite sou CaribTap.',
                    'Majorite tranzaksyon fèt ant itilizate yo; CaribTap ka bay zouti sipò ak revizyon, men li pa toujou aji kòm jij final nan chak dosye.',
                  ],
                ),
                LegalSection(
                  heading: 'Dosye ak prèv',
                  paragraphs: <String>[
                    'Lè gen pwoblèm, toude pati yo dwe prezève mesaj, resi, fakti, foto, videyo, prèv peman, ak nenpòt dokiman ki montre kondisyon tranzaksyon an.',
                    'Dosye ki klè ak konplè ede akselere evalyasyon ka yo epi redwi risk move desizyon.',
                  ],
                ),
                LegalSection(
                  heading: 'Rapò konfli',
                  paragraphs: <String>[
                    'Konfli yo dwe rapòte nan delè rezonab atravè chanèl sipò CaribTap yo. Rapò a dwe dekri pwoblèm nan ak dat kle yo, ansanm ak prèv ki sipòte reklamasyon an.',
                  ],
                ),
                LegalSection(
                  heading: 'Pwosesis revizyon',
                  paragraphs: <String>[
                    'CaribTap ka mande plis detay, tcheke istwa kominikasyon, epi evalye si gen vyolasyon politik. Nou ka sijere rezolisyon, limite kontni, oswa pran mezi sou kont ki pa konfom yo.',
                    'Nan kèk ka, pati yo ka bezwen pouswiv remèd legal oswa administratif deyò platfom nan selon lwa lokal yo.',
                  ],
                ),
                LegalSection(
                  heading: 'Limit responsablite nan konfli',
                  paragraphs: <String>[
                    'Sòf kote lalwa mande otreman, CaribTap pa responsab pou pèt komèsyal oswa domaj konsekansyèl ki soti nan konfli ant itilizate yo. Responsablite prensipal rete sou pati ki fè tranzaksyon an.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'ad_terms_conditions') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Tem ak kondisyon pou anons',
              shortDescription:
                  'Règ kontni piblisite, konfomite, pèfòmans, ak aplikasyon pou anons sou CaribTap.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Akseptasyon ak elijibilite',
                  paragraphs: <String>[
                    'Lè ou soumet oswa peye pou yon anons sou CaribTap, ou dakò ak tem sa yo ansanm ak tout politik platfom ki aplikab. Ou dwe gen otorite legal pou reprezante biznis oswa mak ou ap fè piblisite a.',
                  ],
                ),
                LegalSection(
                  heading: 'Egzijans kontni piblisite',
                  paragraphs: <String>[
                    'Anons yo dwe klè, onèt, epi pa dwe twonpe itilizate yo sou pri, disponiblite, benefis, oswa rezilta espere. Reklamasyon yo dwe soutni pa prèv kote sa nesesè.',
                  ],
                  bulletPoints: <String>[
                    'Pa itilize fo pwomès oswa enfomasyon twonpe',
                    'Respekte dwa mak, imaj, ak pwopriyete entelektyèl',
                    'Evite kontni rayisab, vyolan, pònografik, oswa ilegal',
                    'Asire paj aterisaj yo mache epi koresponn ak anons la',
                  ],
                ),
                LegalSection(
                  heading: 'Revizyon, apwobasyon, ak rejè',
                  paragraphs: <String>[
                    'CaribTap ka revize anons anvan oswa apre piblikasyon. Nou ka apwouve, rejte, sispann, oswa retire anons ki pa konfom, ki kreye risk, oswa ki pa respekte lwa oubyen politik nou yo.',
                  ],
                ),
                LegalSection(
                  heading: 'Peman ak delivrans',
                  paragraphs: <String>[
                    'Depans piblisite yo dwe peye selon metòd faktirasyon ki disponib. Delivrans anons depann de bidjè, odyans, enventè, kalite kontni, ak sistèm optimize platfom nan.',
                    'CaribTap pa garanti yon kantite espesifik klik, lavant, enpresyon, oswa rezilta komèsyal.',
                  ],
                ),
                LegalSection(
                  heading: 'Aksyon sou vyolasyon',
                  paragraphs: <String>[
                    'Vyolasyon tem anons yo ka mennen nan rejè kanpay, sispansyon kont piblisite, limite fonksyon, oswa lot mezi aplikasyon. Ka grav yo ka mennen nan fèmti kont san avi anvan.',
                  ],
                ),
              ],
            ),
          );
        }
        return _normalizeOverride(_LocalizedLegalDocumentOverride(
          title: {
            'privacy_policy': 'Politik konfidansyalite',
            'terms_of_service': 'Tem itilizasyon',
            'marketplace_listing_policy': 'Politik mache ak lis yo',
            'subscription_terms': 'Tem abonnman',
            'trust_safety_policy': 'Politik konfyans ak sekirite',
            'transaction_dispute_policy': 'Politik tranzaksyon ak konfli',
            'ad_terms_conditions': 'Tem ak kondisyon pou anons',
          }[doc.id],
        ));
      case 'nl':
        if (doc.id == 'privacy_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Privacybeleid',
              shortDescription:
                  'Hoe CaribTap persoonsgegevens verzamelt, gebruikt, deelt en beschermt.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Welke gegevens we verzamelen',
                  paragraphs: <String>[
                    'We verzamelen gegevens die je direct verstrekt, zoals naam, e-mailadres, telefoonnummer, profielgegevens, advertentie-inhoud, boekingsinformatie, ondersteuningsberichten en accountvoorkeuren.',
                    'We kunnen ook technische gegevens verzamelen, waaronder apparaat-ID, logboeken, prestatiegegevens, benaderde locatie en gebruikssignalen om functies te verbeteren en misbruik te detecteren.',
                  ],
                ),
                LegalSection(
                  heading: 'Hoe we gegevens gebruiken',
                  paragraphs: <String>[
                    'CaribTap gebruikt gegevens om het platform te laten werken, advertenties en zoekresultaten te tonen, boekingen en abonnementstoegang te beheren, klantenondersteuning te bieden en veiligheidscontroles uit te voeren.',
                    'We kunnen gegevens ook gebruiken voor serviceberichten, beleidsupdates, accountbeveiliging, facturatiecommunicatie en kwaliteitsverbetering.',
                  ],
                ),
                LegalSection(
                  heading: 'Delen en openbaarmaking',
                  paragraphs: <String>[
                    'We kunnen gegevens delen met dienstverleners die hosting, analyses, contentopslag, meldingen, moderatie en ondersteuning leveren. Openbare informatie die je plaatst kan zichtbaar zijn voor andere gebruikers.',
                    'We kunnen gegevens openbaar maken als dit wettelijk vereist is of nodig is om rechten, veiligheid en platformintegriteit te beschermen.',
                  ],
                ),
                LegalSection(
                  heading: 'Bewaring, veiligheid en jouw keuzes',
                  paragraphs: <String>[
                    'We bewaren gegevens zolang dat redelijk nodig is voor dienstverlening, naleving, geschillenafhandeling en fraudepreventie. We passen redelijke technische en organisatorische beveiligingsmaatregelen toe, maar absolute veiligheid kan niet worden gegarandeerd.',
                    'Je kunt bepaalde accountgegevens bijwerken, apparaatmachtigingen beheren en via support verzoeken doen rond toegang of verwijdering, onder voorbehoud van wettelijke bewaarplichten.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'terms_of_service') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Servicevoorwaarden',
              shortDescription:
                  'De basisvoorwaarden voor toegang tot en gebruik van CaribTap.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Acceptatie en toepasselijkheid',
                  paragraphs: <String>[
                    'Door CaribTap te openen of te gebruiken, ga je akkoord met deze Servicevoorwaarden en de aanvullende beleidsdocumenten waarnaar hierin wordt verwezen.',
                    'Als je niet akkoord gaat, mag je de diensten niet gebruiken.',
                  ],
                ),
                LegalSection(
                  heading: 'Rol van het platform',
                  paragraphs: <String>[
                    'CaribTap is een marktplaats- en ontdekkingsplatform dat gebruikers helpt om aanbiedingen te plaatsen, te vinden en met elkaar te communiceren. Tenzij uitdrukkelijk anders vermeld, is CaribTap geen verkoper, verhuurder, betalingsverwerker of garant voor transacties tussen gebruikers.',
                  ],
                ),
                LegalSection(
                  heading: 'Account en inhoudsverantwoordelijkheid',
                  paragraphs: <String>[
                    'Je bent verantwoordelijk voor de juistheid van je accountinformatie, de beveiliging van je inloggegevens en alle activiteiten onder je account.',
                    'Je bent ook volledig verantwoordelijk voor de wettigheid, juistheid en rechten op alle inhoud die je publiceert, inclusief advertenties, afbeeldingen, prijzen en voorwaarden.',
                  ],
                ),
                LegalSection(
                  heading: 'Handhaving en aansprakelijkheidsbeperking',
                  paragraphs: <String>[
                    'CaribTap kan inhoud verwijderen, zichtbaarheid beperken, functies opschorten of accounts beëindigen bij beleidschendingen of veiligheidsrisico\'s.',
                    'Voor zover wettelijk toegestaan is CaribTap niet aansprakelijk voor indirecte of gevolgschade die voortvloeit uit gebruikersgedrag of transacties op het platform.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'marketplace_listing_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Marktplaats- en advertentiebeleid',
              shortDescription:
                  'Regels voor het maken, beheren en publiceren van listings op CaribTap.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Nauwkeurigheid en transparantie',
                  paragraphs: <String>[
                    'Listings moeten duidelijke en waarheidsgetrouwe informatie bevatten over product of dienst, prijs, beschikbaarheid, beperkingen en eventuele aanvullende kosten.',
                    'Misleidende titels, onjuiste foto\'s en verborgen voorwaarden zijn niet toegestaan.',
                  ],
                ),
                LegalSection(
                  heading: 'Verboden inhoud',
                  paragraphs: <String>[
                    'Illegale, gevaarlijke, frauduleuze, vervalste of rechten-schendende aanbiedingen zijn verboden en kunnen zonder waarschuwing worden verwijderd.',
                  ],
                  bulletPoints: <String>[
                    'Illegale goederen of diensten',
                    'Namaakproducten of schending van intellectuele eigendom',
                    'Haatdragende, gewelddadige of expliciet schadelijke inhoud',
                    'Advertenties die gebruikers misleiden of oplichten',
                  ],
                ),
                LegalSection(
                  heading: 'Verantwoordelijkheden van aanbieders',
                  paragraphs: <String>[
                    'Aanbieders zijn verantwoordelijk voor naleving van wet- en regelgeving, vergunningen, belastingen, levering en klantencommunicatie met betrekking tot hun listings.',
                  ],
                ),
                LegalSection(
                  heading: 'Moderatie',
                  paragraphs: <String>[
                    'CaribTap kan listings beoordelen, corrigeren, beperken of verwijderen. Herhaalde schendingen kunnen leiden tot accountmaatregelen of permanente uitsluiting.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'subscription_terms') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Abonnementsvoorwaarden',
              shortDescription:
                  'Voorwaarden voor premiumplannen, facturatie, verlenging en annulering.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Plannen en toegang',
                  paragraphs: <String>[
                    'CaribTap kan meerdere abonnementsniveaus aanbieden met verschillende functies en limieten. De beschikbaarheid kan per regio, apparaat of campagne verschillen.',
                  ],
                ),
                LegalSection(
                  heading: 'Facturatie en automatische verlenging',
                  paragraphs: <String>[
                    'Abonnementen worden doorgaans automatisch verlengd, tenzij je vóór de verlengingsdatum opzegt via het facturatiekanaal dat je gebruikt.',
                    'Aankopen via app stores vallen onder de betalingsregels van Apple of Google.',
                  ],
                ),
                LegalSection(
                  heading: 'Annulering en terugbetalingen',
                  paragraphs: <String>[
                    'Opzegging stopt toekomstige verlengingen, maar beëindigt meestal niet de reeds betaalde periode. Terugbetalingen worden afgehandeld volgens het beleid van de gebruikte betalingsprovider, tenzij de wet anders vereist.',
                  ],
                ),
                LegalSection(
                  heading: 'Misbruik',
                  paragraphs: <String>[
                    'CaribTap kan premiumtoegang beperken of intrekken bij fraude, ongeautoriseerde accountdeling of ander misbruik van abonnementsfuncties.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'trust_safety_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Vertrouwen- en veiligheidsbeleid',
              shortDescription:
                  'Normen voor fraudepreventie, melding, verificatie en handhaving op CaribTap.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Veiligheidsprincipes van het platform',
                  paragraphs: <String>[
                    'CaribTap werkt eraan om een betrouwbare marktplaats te behouden door fraude te verminderen, schadelijke inhoud te verwijderen, transparante interacties te stimuleren en te reageren op geloofwaardige veiligheidszorgen.',
                    'Geen enkele online marktplaats kan alle risico\'s elimineren. Gebruikers moeten voorzichtig zijn en hun eigen oordeel gebruiken bij communiceren, betalen, boeken of afspreken met anderen.',
                  ],
                ),
                LegalSection(
                  heading: 'Oplichtingspreventie en verdachte activiteit',
                  paragraphs: <String>[
                    'CaribTap kan signalen monitoren die samenhangen met verdacht gedrag, waaronder ongebruikelijke accountactiviteit, misleidende advertenties, herhaalde klachten, vervalste betalingsbewijzen, pogingen tot imitatie of patronen die wijzen op fraude of misbruik.',
                    'We kunnen zichtbaarheid beperken, aanvullende informatie opvragen, functies pauzeren of accounttoegang beperken terwijl zorgen worden onderzocht.',
                  ],
                ),
                LegalSection(
                  heading: 'Verificatieverzoeken',
                  paragraphs: <String>[
                    'CaribTap kan gebruikers of bedrijven vragen om informatie of ondersteunende documenten te verstrekken om identiteit, bevoegdheid, eigendom, bedrijfslegitimiteit of advertentienauwkeurigheid te verifiëren. Niet meewerken aan een redelijk verificatieverzoek kan leiden tot beperkte toegang, verwijdering van inhoud of accountmaatregelen.',
                  ],
                ),
                LegalSection(
                  heading: 'Problemen melden',
                  paragraphs: <String>[
                    'Gebruikers moeten vermoedens van fraude, oplichting, misbruik, onveilige advertenties, nepbeoordelingen of beleidschendingen melden via de tools in de app of via supportkanalen.',
                    'Meldingen moeten te goeder trouw worden gedaan en waar mogelijk nauwkeurige details bevatten. Valse of kwaadaardige meldingen kunnen op zichzelf een schending van de platformregels vormen.',
                  ],
                ),
                LegalSection(
                  heading: 'Veiligheidsaanbevelingen voor gebruikers',
                  paragraphs: <String>[
                    'Gebruikers moeten belangrijke details zelfstandig verifiëren voordat zij geld verzenden, gevoelige informatie delen of een huur-, boekings- of dienstafspraak aangaan.',
                  ],
                  bulletPoints: <String>[
                    'Controleer advertentie, profiel en chatgeschiedenis zorgvuldig',
                    'Bevestig data, locatie, prijzen en annuleringsvoorwaarden schriftelijk',
                    'Wees voorzichtig met dringende betaalverzoeken of druk buiten het platform',
                    'Bewaar bewijsstukken van bonnetjes, berichten, offertes, facturen en betalingsbewijzen',
                  ],
                ),
                LegalSection(
                  heading: 'Handhavingsmaatregelen',
                  paragraphs: <String>[
                    'Waar nodig kan CaribTap waarschuwingen geven, advertenties afwijzen, listings verwijderen, bereik verminderen, berichtenverkeer opschorten, transacties beperken, abonnementen beperken of accounts beëindigen. We kunnen ook informatie bewaren voor onderzoeken of zaken doorverwijzen naar relevante autoriteiten waar passend.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'transaction_dispute_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Transactie- en geschillenbeleid',
              shortDescription:
                  'Richtlijnen voor documentatie, melding en afhandeling van geschillen.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Reikwijdte',
                  paragraphs: <String>[
                    'Dit beleid beschrijft hoe geschillen tussen gebruikers rond verkoop, diensten, huur of boekingen op CaribTap worden behandeld.',
                    'In de meeste gevallen zijn transacties directe afspraken tussen gebruikers; CaribTap kan ondersteunen maar is niet in alle situaties beslissende partij.',
                  ],
                ),
                LegalSection(
                  heading: 'Bewijs en administratie',
                  paragraphs: <String>[
                    'Partijen moeten relevante bewijzen bewaren, zoals chats, offertes, facturen, betalingsbewijzen, foto\'s en afspraken over voorwaarden.',
                  ],
                ),
                LegalSection(
                  heading: 'Melden en beoordeling',
                  paragraphs: <String>[
                    'Geschillen moeten tijdig via supportkanalen worden gemeld met duidelijke feiten en ondersteunend materiaal. CaribTap kan aanvullende informatie opvragen en passende platformmaatregelen nemen.',
                  ],
                ),
                LegalSection(
                  heading: 'Beperkingen',
                  paragraphs: <String>[
                    'Voor zover wettelijk toegestaan, is CaribTap niet aansprakelijk voor indirecte verliezen die voortvloeien uit geschillen tussen gebruikers.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'ad_terms_conditions') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'Advertentievoorwaarden',
              shortDescription:
                  'Regels voor advertentie-inhoud, naleving, levering en handhaving.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'Toepassing',
                  paragraphs: <String>[
                    'Door advertenties op CaribTap te plaatsen of te betalen, ga je akkoord met deze advertentievoorwaarden en alle toepasselijke platformregels.',
                  ],
                ),
                LegalSection(
                  heading: 'Inhoudsnormen',
                  paragraphs: <String>[
                    'Advertenties moeten eerlijk, controleerbaar en niet misleidend zijn. Belangrijke prijs- en aanbodvoorwaarden moeten duidelijk worden vermeld.',
                  ],
                  bulletPoints: <String>[
                    'Geen valse claims of verborgen voorwaarden',
                    'Geen inbreuk op merken, auteursrechten of portretrechten',
                    'Geen illegale of schadelijke promotie',
                    'Landingpagina moet relevant en functioneel zijn',
                  ],
                ),
                LegalSection(
                  heading: 'Beoordeling en maatregelen',
                  paragraphs: <String>[
                    'CaribTap kan advertenties goedkeuren, afwijzen, beperken of verwijderen wanneer dat nodig is voor naleving, veiligheid of beleidsintegriteit.',
                  ],
                ),
                LegalSection(
                  heading: 'Levering en resultaten',
                  paragraphs: <String>[
                    'Advertentieresultaten hangen af van budget, doelgroep, voorraad, timing en systeemoptimalisatie. CaribTap garandeert geen specifiek aantal kliks, leads of verkopen.',
                  ],
                ),
              ],
            ),
          );
        }
        return _normalizeOverride(_LocalizedLegalDocumentOverride(
          title: {
            'privacy_policy': 'Privacybeleid',
            'terms_of_service': 'Servicevoorwaarden',
            'marketplace_listing_policy': 'Marktplaats- en advertentiebeleid',
            'subscription_terms': 'Abonnementsvoorwaarden',
            'trust_safety_policy': 'Vertrouwen- en veiligheidsbeleid',
            'transaction_dispute_policy': 'Transactie- en geschillenbeleid',
            'ad_terms_conditions': 'Advertentievoorwaarden',
          }[doc.id],
        ));
      case 'ar':
        if (doc.id == 'privacy_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'سياسة الخصوصية',
              shortDescription:
                  'كيف تجمع CaribTap البيانات الشخصية وتستخدمها وتشاركها وتحميها.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'البيانات التي نجمعها',
                  paragraphs: <String>[
                    'نجمع المعلومات التي تقدمها مباشرة، مثل الاسم والبريد الإلكتروني ورقم الهاتف وبيانات الملف الشخصي ومحتوى القوائم وبيانات الحجز ورسائل الدعم وتفضيلات الحساب.',
                    'وقد نجمع أيضًا بيانات تقنية مثل معرفات الأجهزة وسجلات الاستخدام وبيانات الأداء والموقع التقريبي وإشارات التفاعل لتحسين الخدمة واكتشاف إساءة الاستخدام.',
                  ],
                ),
                LegalSection(
                  heading: 'كيفية استخدام البيانات',
                  paragraphs: <String>[
                    'تستخدم CaribTap البيانات لتشغيل المنصة، وعرض القوائم والإعلانات، وتحسين البحث والتوصيات، وإدارة الحجوزات والاشتراكات، وتقديم الدعم، وتعزيز السلامة والموثوقية.',
                    'وقد نستخدم البيانات أيضًا لإرسال إشعارات الخدمة، وتحديثات السياسات، وتنبيهات الأمان، والرسائل المتعلقة بالفوترة أو الحساب.',
                  ],
                ),
                LegalSection(
                  heading: 'المشاركة والإفصاح',
                  paragraphs: <String>[
                    'قد نشارك المعلومات مع مزودي خدمات يساعدون في الاستضافة والتحليلات والتخزين والإشعارات والاعتدال والدعم الفني. وقد تكون المعلومات التي تنشرها بشكل عام مرئية لمستخدمين آخرين.',
                    'وقد نفصح عن المعلومات إذا كان ذلك مطلوبًا قانونيًا أو ضروريًا لحماية الحقوق أو السلامة أو نزاهة المنصة.',
                  ],
                ),
                LegalSection(
                  heading: 'الاحتفاظ والأمان وخياراتك',
                  paragraphs: <String>[
                    'نحتفظ بالبيانات طالما كان ذلك ضروريًا بشكل معقول لتقديم الخدمة والامتثال القانوني ومنع الاحتيال وتسوية النزاعات. ونطبق تدابير أمنية إدارية وتقنية معقولة، لكن لا يمكن ضمان الأمان المطلق.',
                    'يمكنك تحديث بعض بيانات الحساب، وإدارة أذونات الجهاز، وطلب الوصول أو الحذف عبر قنوات الدعم، مع مراعاة الالتزامات القانونية للاحتفاظ بالبيانات.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'terms_of_service') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'شروط الخدمة',
              shortDescription:
                  'الشروط الأساسية التي تحكم الوصول إلى CaribTap واستخدامه.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'القبول والنطاق',
                  paragraphs: <String>[
                    'باستخدام CaribTap أو الوصول إليه، فإنك توافق على شروط الخدمة هذه وعلى السياسات المرتبطة بها.',
                    'إذا كنت لا توافق على هذه الشروط، فلا يجوز لك استخدام المنصة.',
                  ],
                ),
                LegalSection(
                  heading: 'دور المنصة',
                  paragraphs: <String>[
                    'CaribTap منصة سوق واكتشاف تساعد المستخدمين على نشر القوائم والعثور عليها والتواصل حولها. ما لم يُذكر خلاف ذلك بوضوح، فإن CaribTap ليست بائعًا أو مؤجرًا أو ضامنًا لصفقات المستخدمين.',
                  ],
                ),
                LegalSection(
                  heading: 'الحساب ومسؤولية المحتوى',
                  paragraphs: <String>[
                    'أنت مسؤول عن دقة معلومات حسابك وسرية بيانات الدخول وكل نشاط يتم عبر حسابك.',
                    'وأنت مسؤول أيضًا عن قانونية وصحة وملكية المحتوى الذي تنشره، بما في ذلك الصور والأسعار والأوصاف والشروط.',
                  ],
                ),
                LegalSection(
                  heading: 'التنفيذ وحدود المسؤولية',
                  paragraphs: <String>[
                    'يجوز لـ CaribTap إزالة المحتوى أو تقييد الظهور أو تعليق الميزات أو إنهاء الحسابات عند وجود انتهاكات أو مخاطر.',
                    'إلى الحد الذي يسمح به القانون، لا تتحمل CaribTap المسؤولية عن الأضرار غير المباشرة أو التبعية الناتجة عن سلوك المستخدمين أو المعاملات بينهم.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'marketplace_listing_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'سياسة السوق والقوائم',
              shortDescription:
                  'قواعد إنشاء القوائم وإدارتها ونشرها بشكل صحيح على CaribTap.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'الدقة والشفافية',
                  paragraphs: <String>[
                    'يجب أن تتضمن القوائم معلومات واضحة وصادقة عن المنتج أو الخدمة، بما في ذلك السعر والتوفر والقيود والرسوم الإضافية إن وجدت.',
                    'العناوين المضللة، والصور غير الدقيقة، وإخفاء الشروط الجوهرية غير مسموح بها.',
                  ],
                ),
                LegalSection(
                  heading: 'المحتوى المحظور',
                  paragraphs: <String>[
                    'يُحظر نشر العناصر أو الخدمات غير القانونية أو الخطرة أو الاحتيالية أو المقلدة أو التي تنتهك حقوق الآخرين، وقد تتم إزالتها دون إشعار مسبق.',
                  ],
                  bulletPoints: <String>[
                    'السلع أو الخدمات المخالفة للقانون',
                    'المنتجات المقلدة أو انتهاك الملكية الفكرية',
                    'المحتوى العنيف أو المسيء أو المحرض على الكراهية',
                    'الإعلانات الخادعة أو المصممة للاحتيال على المستخدمين',
                  ],
                ),
                LegalSection(
                  heading: 'مسؤوليات البائع أو المزوّد',
                  paragraphs: <String>[
                    'يتحمل ناشر القائمة مسؤولية الامتثال القانوني والضرائب والتراخيص والتسليم والتواصل مع العملاء بشأن العرض المنشور.',
                  ],
                ),
                LegalSection(
                  heading: 'الاعتدال والتنفيذ',
                  paragraphs: <String>[
                    'يجوز لـ CaribTap مراجعة القوائم وطلب تعديلها أو تقييدها أو إزالتها، وقد تؤدي المخالفات المتكررة إلى إجراءات على الحساب.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'subscription_terms') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'شروط الاشتراك',
              shortDescription:
                  'أحكام الخطط المدفوعة، والفوترة، والتجديد، والإلغاء.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'الخطط وتفعيل الميزات',
                  paragraphs: <String>[
                    'قد تقدم CaribTap مستويات اشتراك متعددة بميزات وحدود مختلفة، وقد تختلف الإتاحة حسب المنطقة أو الجهاز أو الحملة.',
                  ],
                ),
                LegalSection(
                  heading: 'الفوترة والتجديد التلقائي',
                  paragraphs: <String>[
                    'تتجدد الاشتراكات تلقائيًا عادةً ما لم يتم الإلغاء قبل تاريخ التجديد عبر قناة الفوترة المستخدمة.',
                    'عمليات الشراء داخل التطبيق عبر المتاجر تخضع لقواعد Apple أو Google ذات الصلة.',
                  ],
                ),
                LegalSection(
                  heading: 'الإلغاء والاسترداد',
                  paragraphs: <String>[
                    'إلغاء الاشتراك يمنع التجديدات المستقبلية، لكنه غالبًا لا ينهي الفترة المدفوعة الحالية. تتم معالجة الاسترداد وفق سياسات مزود الدفع ما لم ينص القانون على خلاف ذلك.',
                  ],
                ),
                LegalSection(
                  heading: 'إساءة استخدام الاشتراك',
                  paragraphs: <String>[
                    'قد تقيد CaribTap مزايا الاشتراك أو تسحبها في حالات الاحتيال أو مشاركة الوصول غير المصرح بها أو أي استخدام مخالف للسياسات.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'trust_safety_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'سياسة الثقة والسلامة',
              shortDescription:
                  'معايير منع الاحتيال، والإبلاغ، والتحقق، والتنفيذ على CaribTap.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'مبادئ سلامة المنصة',
                  paragraphs: <String>[
                    'تعمل CaribTap على الحفاظ على سوق موثوق من خلال تقليل الاحتيال، وإزالة المحتوى الضار، وتشجيع التفاعلات الشفافة، والاستجابة لمخاوف السلامة الموثوقة.',
                    'لا يمكن لأي سوق عبر الإنترنت إزالة جميع المخاطر. يجب على المستخدمين توخي الحذر واستخدام حكمهم الشخصي عند التواصل أو الدفع أو الحجز أو مقابلة الآخرين.',
                  ],
                ),
                LegalSection(
                  heading: 'منع الاحتيال والنشاط المشبوه',
                  paragraphs: <String>[
                    'قد تراقب CaribTap الإشارات المرتبطة بالسلوك المشبوه، بما في ذلك نشاط الحساب غير المعتاد، والقوائم المضللة، والشكاوى المتكررة، وإثباتات الدفع المزورة، ومحاولات انتحال الهوية، أو الأنماط المتسقة مع الاحتيال أو الإساءة.',
                    'قد نقيد الظهور، أو نطلب معلومات إضافية، أو نوقف ميزات، أو نحد من الوصول إلى الحساب أثناء مراجعة المخاوف.',
                  ],
                ),
                LegalSection(
                  heading: 'طلبات التحقق',
                  paragraphs: <String>[
                    'قد تطلب CaribTap من المستخدمين أو الشركات تقديم معلومات أو مستندات داعمة للتحقق من الهوية أو الصلاحية أو الملكية أو مشروعية النشاط التجاري أو دقة القائمة. وقد يؤدي عدم التعاون مع طلب تحقق معقول إلى تقليل الوصول أو إزالة المحتوى أو اتخاذ إجراء على الحساب.',
                  ],
                ),
                LegalSection(
                  heading: 'الإبلاغ عن المشكلات',
                  paragraphs: <String>[
                    'يجب على المستخدمين الإبلاغ عن الاشتباه في الاحتيال أو النصب أو السلوك المسيء أو القوائم غير الآمنة أو المراجعات المزيفة أو انتهاكات السياسات عبر الأدوات المتاحة في التطبيق أو من خلال قنوات الدعم.',
                    'يجب تقديم البلاغات بحسن نية وأن تتضمن تفاصيل دقيقة قدر الإمكان. وقد يشكل الإبلاغ الكاذب أو الخبيث بحد ذاته انتهاكًا لقواعد المنصة.',
                  ],
                ),
                LegalSection(
                  heading: 'توصيات السلامة للمستخدمين',
                  paragraphs: <String>[
                    'يجب على المستخدمين التحقق بشكل مستقل من التفاصيل المهمة قبل إرسال الأموال أو مشاركة المعلومات الحساسة أو الدخول في ترتيب إيجار أو حجز أو خدمة.',
                  ],
                  bulletPoints: <String>[
                    'راجع القائمة والملف الشخصي وسجل المحادثة بعناية',
                    'أكد التواريخ والموقع والأسعار وتوقعات الإلغاء كتابيًا',
                    'توخ الحذر من طلبات الدفع العاجلة أو الضغوط خارج المنصة',
                    'احتفظ بسجلات الإيصالات والرسائل وعروض الأسعار والفواتير وإثباتات الدفع',
                  ],
                ),
                LegalSection(
                  heading: 'إجراءات التنفيذ',
                  paragraphs: <String>[
                    'عند الاقتضاء، قد تصدر CaribTap تحذيرات، أو ترفض الإعلانات، أو تزيل القوائم، أو تقلل الوصول، أو تعلق المراسلة، أو تحد من المعاملات، أو تقيد الاشتراكات، أو تنهي الحسابات. وقد نحتفظ أيضًا بالمعلومات لأغراض التحقيق أو نحيل المسائل إلى الجهات المختصة عند اللزوم.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'transaction_dispute_policy') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'سياسة المعاملات والنزاعات',
              shortDescription:
                  'إرشادات توثيق المشكلات والإبلاغ عنها ومعالجتها بين المستخدمين.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'النطاق',
                  paragraphs: <String>[
                    'توضح هذه السياسة آلية التعامل مع النزاعات الناشئة عن البيع أو الخدمات أو الإيجار أو الحجوزات التي تتم عبر CaribTap.',
                    'في معظم الحالات تكون المعاملات اتفاقات مباشرة بين المستخدمين، وقد تقدم CaribTap دعمًا إجرائيًا دون أن تكون جهة الفصل النهائية في كل حالة.',
                  ],
                ),
                LegalSection(
                  heading: 'الأدلة والتوثيق',
                  paragraphs: <String>[
                    'يجب على الأطراف الاحتفاظ بالمراسلات والإيصالات والفواتير وإثباتات الدفع والصور وأي شروط متفق عليها لدعم مراجعة النزاع.',
                  ],
                ),
                LegalSection(
                  heading: 'الإبلاغ والمراجعة',
                  paragraphs: <String>[
                    'يجب الإبلاغ عن النزاعات خلال فترة معقولة عبر قنوات الدعم مع شرح واضح للوقائع وإرفاق الأدلة. وقد تطلب CaribTap معلومات إضافية وتتخذ إجراءات مناسبة على المنصة.',
                  ],
                ),
                LegalSection(
                  heading: 'حدود المسؤولية',
                  paragraphs: <String>[
                    'إلى الحد الذي يسمح به القانون، لا تتحمل CaribTap المسؤولية عن الخسائر غير المباشرة الناتجة عن نزاعات بين المستخدمين.',
                  ],
                ),
              ],
            ),
          );
        }
        if (doc.id == 'ad_terms_conditions') {
          return _normalizeOverride(
            const _LocalizedLegalDocumentOverride(
              title: 'شروط وأحكام الإعلانات',
              shortDescription:
                  'قواعد محتوى الإعلانات والامتثال والتسليم والتنفيذ على CaribTap.',
              sections: <LegalSection>[
                LegalSection(
                  heading: 'النطاق والقبول',
                  paragraphs: <String>[
                    'عند نشر إعلان أو الدفع لحملة على CaribTap، فإنك توافق على هذه الشروط وعلى جميع سياسات المنصة ذات الصلة.',
                  ],
                ),
                LegalSection(
                  heading: 'معايير المحتوى الإعلاني',
                  paragraphs: <String>[
                    'يجب أن تكون الإعلانات دقيقة وقابلة للتحقق وغير مضللة، وأن تُفصح بوضوح عن الشروط الجوهرية المتعلقة بالسعر أو العرض.',
                  ],
                  bulletPoints: <String>[
                    'عدم تقديم ادعاءات كاذبة أو إخفاء شروط مهمة',
                    'احترام حقوق العلامات التجارية وحقوق النشر وحقوق الصورة',
                    'عدم الترويج لمحتوى غير قانوني أو ضار',
                    'أن تكون صفحة الهبوط مرتبطة بالإعلان وتعمل بشكل صحيح',
                  ],
                ),
                LegalSection(
                  heading: 'المراجعة والإجراءات',
                  paragraphs: <String>[
                    'يجوز لـ CaribTap مراجعة الإعلانات قبل النشر أو بعده، وقبولها أو رفضها أو تقييدها أو إزالتها عند الحاجة للامتثال أو السلامة أو نزاهة المنصة.',
                  ],
                ),
                LegalSection(
                  heading: 'التسليم والنتائج',
                  paragraphs: <String>[
                    'يعتمد أداء الإعلانات على الميزانية والجمهور والمخزون والتوقيت والتحسين الآلي. لا تضمن CaribTap عددًا محددًا من النقرات أو التحويلات أو المبيعات.',
                  ],
                ),
              ],
            ),
          );
        }
        return _normalizeOverride(_LocalizedLegalDocumentOverride(
          title: {
            'privacy_policy': 'سياسة الخصوصية',
            'terms_of_service': 'شروط الخدمة',
            'marketplace_listing_policy': 'سياسة السوق والقوائم',
            'subscription_terms': 'شروط الاشتراك',
            'trust_safety_policy': 'سياسة الثقة والسلامة',
            'transaction_dispute_policy': 'سياسة المعاملات والنزاعات',
            'ad_terms_conditions': 'شروط وأحكام الإعلانات',
          }[doc.id],
        ));
      default:
        return null;
    }
  }
}

class _LocalizedLegalDocumentOverride {
  final String? title;
  final String? shortDescription;
  final List<LegalSection>? sections;

  const _LocalizedLegalDocumentOverride({
    this.title,
    this.shortDescription,
    this.sections,
  });
}
