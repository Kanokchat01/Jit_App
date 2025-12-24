import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';

/// =========================
/// หน้าแบบสอบถามเชิงลึก
/// =========================
class DeepAssessmentScreen extends StatefulWidget {
  final AppUser user;
  const DeepAssessmentScreen({super.key, required this.user});

  @override
  State<DeepAssessmentScreen> createState() => _DeepAssessmentScreenState();
}

class _DeepAssessmentScreenState extends State<DeepAssessmentScreen> {
  /// คำถามเชิงลึก
  final questions = const [
    '1) คุณรู้สึกสิ้นหวังหรือมองไม่เห็นทางออกของปัญหาหรือไม่',
    '2) คุณรู้สึกว่าความเครียดรบกวนชีวิตประจำวันอย่างมากหรือไม่',
    '3) คุณรู้สึกโดดเดี่ยวหรือไม่มีใครช่วยเหลือหรือไม่',
    '4) คุณมีความคิดทำร้ายตัวเองบ่อยขึ้นหรือไม่',
    '5) คุณรู้สึกว่าควบคุมอารมณ์ของตัวเองไม่ได้หรือไม่',
  ];

  /// ตัวเลือกคำตอบ (0–3)
  final options = const [
    (0, 'ไม่เลย'),
    (1, 'เล็กน้อย'),
    (2, 'ค่อนข้างมาก'),
    (3, 'มากที่สุด'),
  ];

  /// คำตอบ (ยังไม่เลือก = null)
  final List<int?> answers = List<int?>.filled(5, null);

  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final total = answers.fold<int>(0, (p, c) => p + (c ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('แบบสอบถามเชิงลึก'),
        backgroundColor: Colors.orange,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// คะแนนรวม
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'คะแนนรวม: $total',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),

          /// คำถาม
          for (int i = 0; i < questions.length; i++) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      questions[i],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    for (final (val, label) in options)
                      RadioListTile<int>(
                        value: val,
                        groupValue: answers[i],
                        onChanged: saving
                            ? null
                            : (v) => setState(() => answers[i] = v),
                        title: Text(label),
                        dense: true,
                      ),
                  ],
                ),
              ),
            ),
          ],

          /// ปุ่มส่ง
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: saving ? null : _submit,
              child: saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('ส่งแบบสอบถาม'),
            ),
          ),
        ],
      ),
    );
  }

  /// =========================
  /// เมื่อกดส่งแบบสอบถาม
  /// =========================
  Future<void> _submit() async {
    setState(() => saving = true);

    try {
      final safeAnswers = answers.map((e) => e ?? 0).toList();
      final total = safeAnswers.fold<int>(0, (p, c) => p + c);

      /// ตัดสินผล
      /// 0–3 = green | 4–7 = yellow | ≥8 = red
      String deepRisk;
      if (total <= 3) {
        deepRisk = 'green';
      } else if (total <= 7) {
        deepRisk = 'yellow';
      } else {
        deepRisk = 'red';
      }

      if (!mounted) return;

      if (deepRisk == 'green') {
        await _saveResult(deepRisk, total);
        _goBackToGate();
      } else if (deepRisk == 'yellow') {
        _showComeBackLaterDialog(deepRisk, total);
      } else {
        _showAppointmentDialog(deepRisk, total);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// =========================
  /// บันทึกผลลง Firestore
  /// =========================
  Future<void> _saveResult(String risk, int total) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .update({
          'hasCompletedDeepAssessment': true,
          'lastRiskLevel': risk,
          'deepAssessmentScore': total,
          'deepAssessmentAt': FieldValue.serverTimestamp(),
        });
  }

  /// 🟡 เหลือง → แจ้งให้กลับมาทำใหม่
  void _showComeBackLaterDialog(String risk, int total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('คำแนะนำ'),
        content: const Text(
          'ผลการประเมินของคุณอยู่ในระดับที่ควรติดตาม\n'
          'กรุณากลับมาทำแบบประเมินอีกครั้งในภายหลัง',
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _saveResult(risk, total);
              _goBackToGate();
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  /// 🔴 แดง → แนะนำให้นัดแพทย์
  void _showAppointmentDialog(String risk, int total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('ควรพบแพทย์'),
        content: const Text(
          'ผลการประเมินพบว่าคุณมีความเสี่ยงสูง\n'
          'แนะนำให้เข้ารับการปรึกษาจากแพทย์หรือผู้เชี่ยวชาญ',
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _saveResult(risk, total);
              _goBackToGate();
            },
            child: const Text('นัดแพทย์'),
          ),
        ],
      ),
    );
  }

  /// ✅ กลับไป AuthGate / RoleGate
  void _goBackToGate() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}
