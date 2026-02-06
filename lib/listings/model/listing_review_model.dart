import 'package:cloud_firestore/cloud_firestore.dart';

class ListingReviewModel {
  String id;
  String authorID;

  String content;

  int createdAt;

  String firstName;

  String lastName;

  String listingID;

  String profilePictureURL;

  double starCount;

  // Moderation fields
  bool isHidden;
  int? hiddenAt;
  String? hiddenBy;
  String? hiddenReason;

  ListingReviewModel({
      this.id = '',
      this.authorID = '',
      this.content = '',
      createdAt,
      this.firstName = '',
      this.lastName = '',
      this.listingID = '',
      this.profilePictureURL = '',
      this.starCount = 0,
      this.isHidden = false,
      this.hiddenAt,
      this.hiddenBy,
      this.hiddenReason})
      : createdAt = createdAt is int ? createdAt : Timestamp.now().seconds;

  String fullName() => '$firstName $lastName';

  factory ListingReviewModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ListingReviewModel(
        id: doc.id,
        authorID: data['authorID'] ?? '',
        content: data['content'] ?? '',
        createdAt: data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).seconds
            : data['createdAt'],
        firstName: data['firstName'] ?? '',
        lastName: data['lastName'] ?? '',
        listingID: data['listingID'] ?? '',
        profilePictureURL: data['profilePictureURL'] ?? '',
        starCount: (data['starCount'] ?? 0.0).toDouble(),
        isHidden: data['isHidden'] ?? false,
        hiddenAt: data['hiddenAt'] is Timestamp
            ? (data['hiddenAt'] as Timestamp).seconds
            : data['hiddenAt'],
        hiddenBy: data['hiddenBy'],
        hiddenReason: data['hiddenReason']);
  }

  factory ListingReviewModel.fromJson(Map<String, dynamic> parsedJson) {
    return ListingReviewModel(
        id: parsedJson['id'] ?? '',
        authorID: parsedJson['authorID'] ?? '',
        content: parsedJson['content'] ?? '',
        createdAt: parsedJson['createdAt'] is Timestamp
            ? (parsedJson['createdAt'] as Timestamp).seconds
            : parsedJson['createdAt'],
        firstName: parsedJson['firstName'] ?? '',
        lastName: parsedJson['lastName'] ?? '',
        listingID: parsedJson['listingID'] ?? '',
        profilePictureURL: parsedJson['profilePictureURL'] ?? '',
        starCount: (parsedJson['starCount'] ?? 0.0).toDouble(),
        isHidden: parsedJson['isHidden'] ?? false,
        hiddenAt: parsedJson['hiddenAt'] is Timestamp
            ? (parsedJson['hiddenAt'] as Timestamp).seconds
            : parsedJson['hiddenAt'],
        hiddenBy: parsedJson['hiddenBy'],
        hiddenReason: parsedJson['hiddenReason']);
  }

  Map<String, dynamic> toJson() {
    return {
      'authorID': authorID,
      'content': content,
      'createdAt': createdAt,
      'firstName': firstName,
      'lastName': lastName,
      'listingID': listingID,
      'profilePictureURL': profilePictureURL,
      'starCount': starCount,
      'isHidden': isHidden,
      if (hiddenAt != null) 'hiddenAt': hiddenAt,
      if (hiddenBy != null) 'hiddenBy': hiddenBy,
      if (hiddenReason != null) 'hiddenReason': hiddenReason,
    };
  }
}
