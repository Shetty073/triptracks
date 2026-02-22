class User {
  final String id;
  final String email;
  final String username;
  final String? fullName;
  final String? profilePhoto;

  User({
    required this.id,
    required this.email,
    required this.username,
    this.fullName,
    this.profilePhoto,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      fullName: json['full_name'],
      profilePhoto: json['profile_photo'],
    );
  }
}
