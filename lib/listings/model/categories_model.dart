class CategoriesModel {
  final String id;
  final String title;
  final String photo;
  final bool isActive;
  final int sortOrder;

  CategoriesModel({
    required this.id,
    required this.title,
    required this.photo,
    required this.isActive,
    required this.sortOrder,
  });

  factory CategoriesModel.fromJson(
      Map<String, dynamic> json, {
        required String id,
      }) {
    final title = (json['title'] ?? json['name'] ?? '') as String;

    final photo = (json['photo'] ??
        json['photoUrl'] ??
        json['image'] ??
        json['icon'] ??
        '') as String;

    return CategoriesModel(
      id: id,
      title: title,
      photo: photo,
      isActive: (json['isActive'] ?? true) as bool,
      sortOrder: (json['sortOrder'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'photo': photo,
    'isActive': isActive,
    'sortOrder': sortOrder,
  };
}
