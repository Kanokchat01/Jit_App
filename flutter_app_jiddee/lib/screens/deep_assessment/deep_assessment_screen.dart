import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../patient/appointment_screen.dart';

class DeepAssessmentScreen extends StatefulWidget {
  final AppUser user;
  const DeepAssessmentScreen({super.key, required this.user});

  @override
  State<DeepAssessmentScreen> createState() => _DeepAssessmentScreenState();
}

class _DeepAssessmentScreenState extends State<DeepAssessmentScreen> {
  final questions = const [
    '1) คุณรู้สึกสิ้นหวังหรือมองไม่เห็นทางออกของปัญหาหรือไม่',
    '2) คุณรู้สึกว่าความเครียดรบกวนชีวิตประจำวันอย่างมากหรือไม่',
    '3) คุณรู้สึกโดดเดี่ยวหรือไม่มีใครช่วยเหลือหรือไม่',
    '4) คุณมีความคิดทำร้ายตัวเองบ่อยขึ้นหรือไม่',
    '5) คุณรู้สึกว่าควบคุมอารมณ์ของตัวเองไม่ได้หรือไม่',
  ];

  final options = const [
    (0, 'ไม่เลย'),
    (1, 'เล็กน้อย'),
    (2, 'ค่อนข้างมาก'),
    (3, 'มากที่สุด'),
  ];

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

  void _submit() {
    final safeAnswers = answers.map((e) => e ?? 0).toList();
    final total = safeAnswers.fold<int>(0, (p, c) => p + c);

    String deepRisk;
    if (total <= 3) {
      deepRisk = 'green';
    } else if (total <= 7) {
      deepRisk = 'yellow';
    } else {
      deepRisk = 'red';
    }

    _showResultDialog(deepRisk, total);
  }

  void _showResultDialog(String risk, int total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('ผลการประเมิน'),
        content: Text(
          risk == 'green'
              ? 'ผลการประเมินอยู่ในระดับปลอดภัย (สีเขียว)'
              : risk == 'yellow'
              ? 'ผลการประเมินอยู่ในระดับควรติดตาม (สีเหลือง)\nกรุณากลับมาทำแบบประเมินอีกครั้ง'
              : 'ผลการประเมินอยู่ในระดับความเสี่ยงสูง (สีแดง)\nแนะนำให้เข้ารับการปรึกษาแพทย์',
        ),
        actions: [
          ElevatedButton(
            child: const Text('ตกลง'),
            onPressed: () async {
              Navigator.pop(context);

              if (risk == 'red') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AppointmentScreen(user: widget.user),
                  ),
                );
              }

              await _saveResult(risk, total);

              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveResult(String risk, int total) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .update({
          'hasCompletedDeepAssessment': true,
          'deepRiskLevel': risk,
          'deepAssessmentScore': total,
          'deepAssessmentAt': FieldValue.serverTimestamp(),
        });
  }
}
