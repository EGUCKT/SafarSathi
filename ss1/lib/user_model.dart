/// User model for representing authenticated user data.
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? homeLocation;

  /// Creates a new UserModel instance.
  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.homeLocation,
  });

  /// Converts UserModel to a JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'homeLocation': homeLocation,
    };
  }

  /// Creates a new UserModel from a map (useful for deserialization).
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      email: map['email'] as String,
      name: map['name'] as String,
      homeLocation: map['homeLocation'] as String?,
    );
  }

  /// Returns a copy of this UserModel with specified fields replaced.
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? homeLocation,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      homeLocation: homeLocation ?? this.homeLocation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          name == other.name &&
          homeLocation == other.homeLocation;

  @override
  int get hashCode =>
      uid.hashCode ^ email.hashCode ^ name.hashCode ^ homeLocation.hashCode;

  @override
  String toString() =>
      'UserModel(uid: $uid, email: $email, name: $name, homeLocation: $homeLocation)';
}