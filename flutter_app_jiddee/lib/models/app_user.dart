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
  final String email;
  final UserRole role;
  final bool consentCamera;

  // student profile
  final String? phone;
  final String? birthDate;
  final String? faculty;
  final String? major;
  final String? studentId;
  final String? year;

  // optional
  final String? age;
  final String? gender;

  // PHQ-9
  final bool hasCompletedPhq9;
  final String? phq9RiskLevel;

  // Deep Assessment
  final bool hasCompletedDeepAssessment;
  final String? deepRiskLevel;
  final int? deepScore;

  // ✅ Emotion Detection (On-device)
  final int? emotionSamples;
  final double? emotionAvgConf;
  final String? dominantEmotion;
  final double? dominantScore;
  final Map<String, double>? emotionSummaryPercent;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.consentCamera,
    required this.hasCompletedPhq9,
    required this.hasCompletedDeepAssessment,

    this.phone,
    this.birthDate,
    this.faculty,
    this.major,
    this.studentId,
    this.year,
    this.age,
    this.gender,
    this.phq9RiskLevel,
    this.deepRiskLevel,
    this.deepScore,
    this.emotionSamples,
    this.emotionAvgConf,
    this.dominantEmotion,
    this.dominantScore,
    this.emotionSummaryPercent,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,

      role: roleFromString((data['role'] ?? 'patient') as String),
      consentCamera: (data['consentCamera'] ?? false) as bool,

      phone: data['phone'] as String?,
      birthDate: data['birthDate'] as String?,
      faculty: data['faculty'] as String?,
      major: data['major'] as String?,
      studentId: data['studentId'] as String?,
      year: data['year'] as String?,

      age: data['age'] as String?,
      gender: data['gender'] as String?,

      hasCompletedPhq9: (data['hasCompletedPhq9'] ?? false) as bool,
      phq9RiskLevel: data['phq9RiskLevel'] as String?,

      hasCompletedDeepAssessment:
          (data['hasCompletedDeepAssessment'] ?? false) as bool,
      deepRiskLevel: data['deepRiskLevel'] as String?,
      deepScore: data['deepScore'] is int ? data['deepScore'] as int : null,

      // ✅ Parse deepEmotion nested map
      emotionSamples: _emoInt(data, 'samples'),
      emotionAvgConf: _emoDouble(data, 'avgConf'),
      dominantEmotion: _emoString(data, 'dominant'),
      dominantScore: _emoDouble(data, 'dominantScore'),
      emotionSummaryPercent: _emoPercent(data),
    );
  }

  static int? _emoInt(Map<String, dynamic> data, String key) {
    final e = data['deepEmotion'];
    if (e is! Map) return null;
    final v = e[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  static double? _emoDouble(Map<String, dynamic> data, String key) {
    final e = data['deepEmotion'];
    if (e is! Map) return null;
    final v = e[key];
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return null;
  }

  static String? _emoString(Map<String, dynamic> data, String key) {
    final e = data['deepEmotion'];
    if (e is! Map) return null;
    final v = e[key];
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  static Map<String, double>? _emoPercent(Map<String, dynamic> data) {
    final e = data['deepEmotion'];
    if (e is! Map) return null;
    final sp = e['summaryPercent'];
    if (sp is! Map) return null;
    final result = <String, double>{};
    for (final entry in sp.entries) {
      result[entry.key.toString()] = (entry.value is num) ? (entry.value as num).toDouble() : 0.0;
    }
    return result.isEmpty ? null : result;
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': roleToString(role),
      'consentCamera': consentCamera,
      'phone': phone,
      'birthDate': birthDate,
      'faculty': faculty,
      'major': major,
      'studentId': studentId,
      'year': year,
      'age': age,
      'gender': gender,
      'hasCompletedPhq9': hasCompletedPhq9,
      'phq9RiskLevel': phq9RiskLevel,
      'hasCompletedDeepAssessment': hasCompletedDeepAssessment,
      'deepRiskLevel': deepRiskLevel,
      'deepScore': deepScore,
      if (emotionSamples != null || dominantEmotion != null)
        'deepEmotion': {
          'samples': emotionSamples ?? 0,
          'avgConf': emotionAvgConf ?? 0.0,
          'dominant': dominantEmotion ?? '',
          'dominantScore': dominantScore ?? 0.0,
          'summaryPercent': emotionSummaryPercent ?? <String, double>{},
        },
    };
  }
}
