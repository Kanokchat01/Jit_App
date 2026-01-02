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

  // profile (optional)
  final String? phone;
  final String? age;
  final String? gender;

  // PHQ-9
  final bool hasCompletedPhq9;
  final String? phq9RiskLevel;

  // Deep Assessment (TMHI-55)
  final bool hasCompletedDeepAssessment;
  final String? deepRiskLevel;
  final int? deepScore;

  const AppUser({
    required this.uid,
    required this.name,
    required this.role,
    required this.consentCamera,
    required this.hasCompletedPhq9,
    required this.hasCompletedDeepAssessment,
    this.phq9RiskLevel,
    this.deepRiskLevel,
    this.deepScore,
    this.phone,
    this.age,
    this.gender,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      name: (data['name'] ?? '') as String,
      role: roleFromString((data['role'] ?? 'patient') as String),
      consentCamera: (data['consentCamera'] ?? false) as bool,

      phone: data['phone'] as String?,
      age: data['age'] as String?,
      gender: data['gender'] as String?,

      hasCompletedPhq9: (data['hasCompletedPhq9'] ?? false) as bool,
      phq9RiskLevel: data['phq9RiskLevel'] as String?,

      hasCompletedDeepAssessment:
          (data['hasCompletedDeepAssessment'] ?? false) as bool,
      deepRiskLevel: data['deepRiskLevel'] as String?,
      deepScore: (data['deepScore'] is int) ? data['deepScore'] as int? : null,
    );
  }
}
