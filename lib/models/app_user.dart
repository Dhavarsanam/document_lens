/// Lightweight user profile — mirrors the signed-in Firebase Auth user.
/// (No local Hive storage anymore; Firebase Auth is the source of truth.)
class AppUser {
  final String uid;
  final String name;
  final String email;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
  });
}