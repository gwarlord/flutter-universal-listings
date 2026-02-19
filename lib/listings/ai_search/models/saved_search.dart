import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'search_interpretation.dart';

/// Saved search model
class SavedSearch extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String originalQuery;
  final SearchInterpretation interpretation;
  final bool notificationsEnabled;
  final DateTime createdAt;
  final DateTime lastRunAt;
  final int matchCountAtLastRun;

  const SavedSearch({
    required this.id,
    required this.userId,
    required this.name,
    required this.originalQuery,
    required this.interpretation,
    this.notificationsEnabled = false,
    required this.createdAt,
    required this.lastRunAt,
    this.matchCountAtLastRun = 0,
  });

  factory SavedSearch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavedSearch(
      id: doc.id,
      userId: data['userId'] as String,
      name: data['name'] as String,
      originalQuery: data['originalQuery'] as String,
      interpretation: SearchInterpretation.fromJson(
        data['interpretation'] as Map<String, dynamic>,
      ),
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastRunAt: (data['lastRunAt'] as Timestamp).toDate(),
      matchCountAtLastRun: data['matchCountAtLastRun'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'originalQuery': originalQuery,
      'interpretation': interpretation.toJson(),
      'notificationsEnabled': notificationsEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastRunAt': Timestamp.fromDate(lastRunAt),
      'matchCountAtLastRun': matchCountAtLastRun,
    };
  }

  SavedSearch copyWith({
    String? id,
    String? userId,
    String? name,
    String? originalQuery,
    SearchInterpretation? interpretation,
    bool? notificationsEnabled,
    DateTime? createdAt,
    DateTime? lastRunAt,
    int? matchCountAtLastRun,
  }) {
    return SavedSearch(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      originalQuery: originalQuery ?? this.originalQuery,
      interpretation: interpretation ?? this.interpretation,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      matchCountAtLastRun: matchCountAtLastRun ?? this.matchCountAtLastRun,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        originalQuery,
        interpretation,
        notificationsEnabled,
        createdAt,
        lastRunAt,
        matchCountAtLastRun,
      ];
}
