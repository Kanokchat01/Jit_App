enum UserRole { patient, clinician, admin }

UserRole roleFromString(String s) {
  switch (s) {
    case 'clinician':
      return UserRole.clinician;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.patient;
  }
}

String roleToString(UserRole r) {
  switch (r) {
    case UserRole.patient:
      return 'patient';
    case UserRole.clinician:
      return 'clinician';
    case UserRole.admin:
      return 'admin';
  }
}

class AppUser {
  final String uid;
  final String name;
  final UserRole role;
  final bool consentCamera;
  final String? lastRiskLevel;

  AppUser({
    required this.uid,
    required this.name,
    required this.role,
    required this.consentCamera,
    this.lastRiskLevel,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      name: (data['name'] ?? '') as String,
      role: roleFromString((data['role'] ?? 'patient') as String),
      consentCamera: (data['consentCamera'] ?? false) as bool,
      lastRiskLevel: data['lastRiskLevel'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'role': roleToString(role),
        'consentCamera': consentCamera,
        'lastRiskLevel': lastRiskLevel,
      };
}
