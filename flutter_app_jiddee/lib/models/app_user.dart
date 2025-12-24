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

  final bool hasCompletedPhq9;
  final bool hasCompletedDeepAssessment;

  final String? lastRiskLevel;

  const AppUser({
    required this.uid,
    required this.name,
    required this.role,
    required this.consentCamera,
    required this.hasCompletedPhq9,
    required this.hasCompletedDeepAssessment,
    this.lastRiskLevel,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      name: (data['name'] ?? '') as String,
      role: roleFromString((data['role'] ?? 'patient') as String),
      consentCamera: (data['consentCamera'] ?? false) as bool,
      hasCompletedPhq9: (data['hasCompletedPhq9'] ?? false) as bool,
      hasCompletedDeepAssessment:
          (data['hasCompletedDeepAssessment'] ?? false) as bool,
      lastRiskLevel: data['lastRiskLevel'] as String?,
    );
  }
}
