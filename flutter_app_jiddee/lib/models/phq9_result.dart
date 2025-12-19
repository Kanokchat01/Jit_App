class Phq9Result {
  final String uid;
  final List<int> answers; // 9 items, 0..3
  final int scoreTotal;
  final String severity;
  final String riskLevel; // green/yellow/red
  final DateTime createdAt;

  Phq9Result({
    required this.uid,
    required this.answers,
    required this.scoreTotal,
    required this.severity,
    required this.riskLevel,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'answers': answers,
        'scoreTotal': scoreTotal,
        'severity': severity,
        'riskLevel': riskLevel,
        'createdAt': createdAt, // Firestore รองรับ DateTime
      };
}

({String severity, String riskLevel}) classifyPhq9(List<int> a) {
  final total = a.fold<int>(0, (p, c) => p + c);

  String severity;
  if (total <= 4) severity = 'Minimal';
  else if (total <= 9) severity = 'Mild';
  else if (total <= 14) severity = 'Moderate';
  else if (total <= 19) severity = 'Moderately Severe';
  else severity = 'Severe';

  // MVP risk rules
  String risk;
  if (a.length >= 9 && a[8] > 0) {
    risk = 'red'; // self-harm flag
  } else if (total <= 4) {
    risk = 'green';
  } else if (total <= 14) {
    risk = 'yellow';
  } else {
    risk = 'red';
  }

  return (severity: severity, riskLevel: risk);
}
