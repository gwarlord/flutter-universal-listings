import 'package:cloud_firestore/cloud_firestore.dart';

class ListingModel {
  String authorID;
  String authorName;
  String authorProfilePic;

  String categoryID;
  String categoryPhoto;
  String categoryTitle;

  int createdAt;
  String description;

  /// Optional. Can be empty.
  Map<String, dynamic> filters;

  String id;
  bool isApproved;

  double latitude;
  double longitude;

  String photo;
  List<String> photos;

  String place;

  /// Optional. For services/venues this may be empty.
  String price;

  /// Optional contact info.
  String phone;
  String email;
  String website;

  /// Optional opening hours (free-form text).
  String openingHours;

  num reviewsCount;
  num reviewsSum;

  String title;

  // internal use only, don't save to db
  bool isFav = false;

  ListingModel({
    this.authorID = '',
    this.authorName = '',
    this.authorProfilePic = '',
    this.categoryID = '',
    this.categoryPhoto = '',
    this.categoryTitle = '',
    createdAt,
    this.description = '',
    this.filters = const {},
    this.id = '',
    this.isApproved = false,
    this.latitude = 0.1,
    this.longitude = 0.1,
    this.photo = '',
    this.photos = const [],
    this.place = '',
    this.price = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.openingHours = '',
    this.reviewsCount = 0,
    this.reviewsSum = 0,
    this.title = '',
  }) : createdAt = createdAt is int ? createdAt : Timestamp.now().seconds;

  factory ListingModel.fromJson(Map<String, dynamic> parsedJson) {
    return ListingModel(
      authorID: parsedJson['authorID'] ?? '',
      authorName: parsedJson['authorName'] ?? '',
      authorProfilePic: parsedJson['authorProfilePic'] ?? '',
      categoryID: parsedJson['categoryID'] ?? '',
      categoryPhoto: parsedJson['categoryPhoto'] ?? '',
      categoryTitle: parsedJson['categoryTitle'] ?? '',
      createdAt: parsedJson['createdAt'] is Timestamp
          ? (parsedJson['createdAt'] as Timestamp).seconds
          : parsedJson['createdAt'],
      description: parsedJson['description'] ?? '',
      filters: parsedJson['filters'] ?? {},
      id: parsedJson['id'] ?? '',
      isApproved: parsedJson['isApproved'] ?? false,
      latitude: (parsedJson['latitude'] ?? 0.1).toDouble(),
      longitude: (parsedJson['longitude'] ?? 0.1).toDouble(),
      photo: parsedJson['photo'] ?? '',
      photos: List<String>.from(parsedJson['photos'] ?? []),
      place: parsedJson['place'] ?? '',
      price: parsedJson['price'] ?? '',
      phone: parsedJson['phone'] ?? '',
      email: parsedJson['email'] ?? '',
      website: parsedJson['website'] ?? '',
      openingHours: parsedJson['openingHours'] ?? '',
      reviewsCount: parsedJson['reviewsCount'] ?? 0,
      reviewsSum: parsedJson['reviewsSum'] ?? 0,
      title: parsedJson['title'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'authorID': authorID,
      'authorName': authorName,
      'authorProfilePic': authorProfilePic,
      'categoryID': categoryID,
      'categoryPhoto': categoryPhoto,
      'categoryTitle': categoryTitle,
      'createdAt': createdAt,
      'description': description,
      'filters': filters,
      'id': id,
      'isApproved': isApproved,
      'latitude': latitude,
      'longitude': longitude,
      'photo': photo,
      'photos': photos,
      'place': place,
      'price': price,
      'phone': phone,
      'email': email,
      'website': website,
      'openingHours': openingHours,
      'reviewsCount': reviewsCount,
      'reviewsSum': reviewsSum,
      'title': title,
    };
  }
}
