import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/app_user.dart';
import '../../models/phq9_result.dart';
import '../../services/firestore_service.dart';

import '../deep_assessment/deep_assessment_screen.dart';

class Phq9Screen extends StatefulWidget {
  final AppUser user;
  const Phq9Screen({super.key, required this.user});

  @override
  State<Phq9Screen> createState() => _Phq9ScreenState();
}

class _Phq9ScreenState extends State<Phq9Screen> {
  /// คำถาม PHQ-9
  final questions = const [
    '1) ในช่วง 2 สัปดาห์ที่ผ่านมา คุณรู้สึกไม่สนใจหรือไม่เพลิดเพลินกับการทำสิ่งต่าง ๆ หรือไม่',
    '2) ในช่วง 2 สัปดาห์ที่ผ่านมา คุณรู้สึกหดหู่ เศร้า หรือสิ้นหวังหรือไม่',
    '3) คุณมีปัญหาในการนอนหลับ เช่น นอนหลับยาก หลับไม่สนิท หรือหลับมากเกินไปหรือไม่',
    '4) คุณรู้สึกเหนื่อย อ่อนเพลีย หรือไม่มีแรงหรือไม่',
    '5) คุณเบื่ออาหาร หรือรับประทานอาหารมากเกินไปหรือไม่',
    '6) คุณรู้สึกไม่ดีกับตัวเอง รู้สึกว่าตัวเองล้มเหลว หรือทำให้ครอบครัวผิดหวังหรือไม่',
    '7) คุณมีปัญหาในการจดจ่อหรือมีสมาธิ เช่น อ่านหนังสือหรือดูโทรทัศน์หรือไม่',
    '8) คุณเคลื่อนไหวหรือพูดช้ากว่าปกติ หรือกระสับกระส่ายมากกว่าปกติหรือไม่',
    '9) คุณมีความคิดว่าถ้าตายไปคงจะดีกว่า หรือคิดทำร้ายตัวเองหรือไม่',
  ];

  final options = const [
    (0, 'ไม่เลย'),
    (1, 'เป็นบางวัน'),
    (2, 'เป็นบ่อยกว่าครึ่งหนึ่งของวัน'),
    (3, 'เป็นเกือบทุกวัน'),
  ];

  /// ใช้ int? เพื่อให้ยังไม่เลือก → ไม่มีจุดสี
  final List<int?> answers = List<int?>.filled(9, null);

  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blue.shade700;
    final total = answers.fold<int>(0, (p, c) => p + (c ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('แบบประเมิน PHQ-9'),
        backgroundColor: primaryColor,
      ),
      backgroundColor: Colors.blue.shade50,
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
              'คะแนนรวมปัจจุบัน: $total',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
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
                  : const Text('ส่งแบบประเมิน'),
            ),
          ),
        ],
      ),
    );
  }

  /// =========================
  /// Submit PHQ-9
  /// =========================
  Future<void> _submit() async {
    setState(() => saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final safeAnswers = answers.map((e) => e ?? 0).toList();
      final total = safeAnswers.fold<int>(0, (p, c) => p + c);
      final cls = classifyPhq9(safeAnswers);

      final result = Phq9Result(
        uid: uid,
        answers: safeAnswers,
        scoreTotal: total,
        severity: cls.severity,
        riskLevel: cls.riskLevel,
        createdAt: DateTime.now(),
      );

      await FirestoreService().savePhq9Result(result);

      if (!mounted) return;

      _showResultDialog(cls.riskLevel);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// =========================
  /// Dialog แสดงผลหลังส่ง
  /// =========================
  void _showResultDialog(String risk) {
    final bool isGreen = risk == 'green';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(isGreen ? 'ผลการประเมิน' : 'ต้องทำแบบประเมินเพิ่มเติม'),
        content: Text(
          isGreen
              ? 'สถานะ/อาการของคุณอยู่ในระดับสีเขียว\n'
                    'ปลอดภัย หายห่วง'
              : 'สถานะ/อาการของคุณอยู่ในระดับสี${risk == 'yellow' ? 'เหลือง' : 'แดง'}\n'
                    'คุณจำเป็นต้องทำแบบประเมินเชิงลึกต่อ',
        ),
        actions: [
          ElevatedButton(
            child: const Text('ตกลง'),
            onPressed: () {
              Navigator.of(context).pop();

              if (isGreen) {
                /// กลับ Home (ให้ RoleGate จัดการ)
                Navigator.popUntil(context, (route) => route.isFirst);
              } else {
                /// ไปแบบสอบถามเชิงลึก
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeepAssessmentScreen(user: widget.user),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
