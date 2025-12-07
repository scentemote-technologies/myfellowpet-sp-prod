class User {
  final String uid;
  final String name;

  User(this.uid, this.name);

  // Add fromMap method to create a User instance from a Firestore document
  factory User.fromMap(Map<String, dynamic> data, String uid) {
    return User(
      uid,
      data['name'] ?? 'No Name',
    );
  }
}
