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

  // =========================
  // PHQ-9
  // =========================
  final bool hasCompletedPhq9;
  final String? phq9RiskLevel;

  // =========================
  // Deep Assessment
  // =========================
  final bool hasCompletedDeepAssessment;
  final String? deepRiskLevel;

  const AppUser({
    required this.uid,
    required this.name,
    required this.role,
    required this.consentCamera,
    required this.hasCompletedPhq9,
    required this.hasCompletedDeepAssessment,
    this.phq9RiskLevel,
    this.deepRiskLevel,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      name: (data['name'] ?? '') as String,
      role: roleFromString((data['role'] ?? 'patient') as String),
      consentCamera: (data['consentCamera'] ?? false) as bool,

      // PHQ-9
      hasCompletedPhq9: (data['hasCompletedPhq9'] ?? false) as bool,
      phq9RiskLevel: data['phq9RiskLevel'] as String?,

      // Deep Assessment
      hasCompletedDeepAssessment:
          (data['hasCompletedDeepAssessment'] ?? false) as bool,
      deepRiskLevel: data['deepRiskLevel'] as String?,
    );
  }
}
