import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/deal_ad_model.dart';

/// Explainability chip for search results
class ExplainabilityChip extends Equatable {
  final String label;
  final IconData icon;
  final Color color;

  const ExplainabilityChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  List<Object?> get props => [label, icon, color];
}

/// Search result wrapper with scoring and explainability
class SearchResult extends Equatable {
  final ListingModel? listing;
  final DealAdModel? deal;
  final double matchScore;
  final List<ExplainabilityChip> explainabilityChips;
  final double? distance;

  const SearchResult({
    this.listing,
    this.deal,
    required this.matchScore,
    this.explainabilityChips = const [],
    this.distance,
  });

  factory SearchResult.fromListing({
    required ListingModel listing,
    required double matchScore,
    List<ExplainabilityChip>? explainabilityChips,
    double? distance,
  }) {
    return SearchResult(
      listing: listing,
      matchScore: matchScore,
      explainabilityChips: explainabilityChips ?? [],
      distance: distance,
    );
  }

  factory SearchResult.fromDeal({
    required DealAdModel deal,
    required double matchScore,
    List<ExplainabilityChip>? explainabilityChips,
    double? distance,
  }) {
    return SearchResult(
      deal: deal,
      matchScore: matchScore,
      explainabilityChips: explainabilityChips ?? [],
      distance: distance,
    );
  }

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      listing: json['listing'] != null
          ? ListingModel.fromJson(json['listing'] as Map<String, dynamic>)
          : null,
      deal: null, // DealAdModel doesn't have fromJson, will be set separately if needed
      matchScore: (json['matchScore'] as num?)?.toDouble() ?? 0.0,
      explainabilityChips: (json['explainabilityChips'] as List<dynamic>?)
              ?.map((e) => _chipFromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      distance: (json['distance'] as num?)?.toDouble(),
    );
  }

  static ExplainabilityChip _chipFromJson(Map<String, dynamic> json) {
    final label = json['label'] as String;
    final iconCode = json['iconCode'] as int? ?? Icons.info.codePoint;
    final colorValue = json['colorValue'] as int? ?? Colors.blue.value;

    return ExplainabilityChip(
      label: label,
      icon: IconData(iconCode, fontFamily: 'MaterialIcons'),
      color: Color(colorValue),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (listing != null) 'listing': listing!.toJson(),
      if (deal != null) 'deal': deal!.toMap(),
      'matchScore': matchScore,
      'explainabilityChips': explainabilityChips
          .map((chip) => {
                'label': chip.label,
                'iconCode': chip.icon.codePoint,
                'colorValue': chip.color.value,
              })
          .toList(),
      if (distance != null) 'distance': distance,
    };
  }

  String get id => listing?.id ?? deal?.id ?? '';
  String get title => listing?.title ?? deal?.caption ?? '';

  @override
  List<Object?> get props => [listing, deal, matchScore, explainabilityChips, distance];
}
