import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/app_user.dart';
import '../../models/phq9_result.dart';
import '../../services/firestore_service.dart';

class Phq9Screen extends StatefulWidget {
  final AppUser user;
  final bool fromHome;

  const Phq9Screen({super.key, required this.user, this.fromHome = false});

  @override
  State<Phq9Screen> createState() => _Phq9ScreenState();
}

class _Phq9ScreenState extends State<Phq9Screen> {
  // ✅ mascot (ตกแต่งอย่างเดียว)
  static const String _mascotAsset = 'assets/images/jitdee_mascot.png';

  final questions = const [
    ' ในช่วง 2 สัปดาห์ที่ผ่านมา คุณรู้สึกไม่สนใจหรือไม่เพลิดเพลินกับการทำสิ่งต่าง ๆ หรือไม่',
    ' ในช่วง 2 สัปดาห์ที่ผ่านมา คุณรู้สึกหดหู่ เศร้า หรือสิ้นหวังหรือไม่',
    ' คุณมีปัญหาในการนอนหลับ เช่น นอนหลับยาก หลับไม่สนิท หรือหลับมากเกินไปหรือไม่',
    ' คุณรู้สึกเหนื่อย อ่อนเพลีย หรือไม่มีแรงหรือไม่',
    ' คุณเบื่ออาหาร หรือรับประทานอาหารมากเกินไปหรือไม่',
    ' คุณรู้สึกไม่ดีกับตัวเอง รู้สึกว่าตัวเองล้มเหลว หรือทำให้ครอบครัวผิดหวังหรือไม่',
    ' คุณมีปัญหาในการจดจ่อหรือมีสมาธิ เช่น อ่านหนังสือหรือดูโทรทัศน์หรือไม่',
    ' คุณเคลื่อนไหวหรือพูดช้ากว่าปกติ หรือกระสับกระส่ายมากกว่าปกติหรือไม่',
    ' คุณมีความคิดว่าถ้าตายไปคงจะดีกว่า หรือคิดทำร้ายตัวเองหรือไม่',
  ];

  final options = const [
    (0, 'ไม่เลย'),
    (1, 'เป็นบางวัน'),
    (2, 'เป็นบ่อยกว่าครึ่งหนึ่งของวัน'),
    (3, 'เป็นเกือบทุกวัน'),
  ];

  final List<int?> answers = List<int?>.filled(9, null);
  bool saving = false;

  int get _total => answers.fold<int>(0, (p, c) => p + (c ?? 0));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('แบบประเมิน PHQ-9'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black.withOpacity(0.82),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // ✅ logic เดิม
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.secondary.withOpacity(0.22),
              cs.primary.withOpacity(0.12),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            children: [
              _scoreHero(context),
              const SizedBox(height: 16),

              _sectionTitle(context, "ตอบคำถามให้ครบ 9 ข้อ"),
              const SizedBox(height: 12),

              for (int i = 0; i < questions.length; i++) ...[
                _questionCard(
                  context: context,
                  index: i,
                  question: questions[i],
                ),
                const SizedBox(height: 14),
              ],

              const SizedBox(height: 4),
              _submitButton(context),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // UI Widgets (ตกแต่งเท่านั้น)
  // =========================

  Widget _scoreHero(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.78),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // bubbles background
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.secondary.withOpacity(0.18),
                ),
              ),
            ),
            Positioned(
              left: -70,
              bottom: -80,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withOpacity(0.10),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.analytics_outlined, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "คะแนนรวมปัจจุบัน",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black.withOpacity(0.78),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: cs.primary.withOpacity(0.20),
                                ),
                              ),
                              child: Text(
                                "${_total}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: cs.primary.withOpacity(0.95),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "จาก 27 คะแนน",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // mascot
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        _mascotAsset,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _questionCard({
    required BuildContext context,
    required int index,
    required String question,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.90),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 15.2,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: Colors.black.withOpacity(0.82),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // options
          for (final (val, label) in options)
            _optionTile<int>(
              context: context,
              value: val,
              groupValue: answers[index],
              onChanged: saving ? null : (v) => setState(() => answers[index] = v),
              label: label,
            ),
        ],
      ),
    );
  }

  Widget _optionTile<T>({
    required BuildContext context,
    required T value,
    required T? groupValue,
    required ValueChanged<T?>? onChanged,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selected = value == groupValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected
            ? cs.primary.withOpacity(0.10)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? cs.primary.withOpacity(0.35)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: RadioListTile<T>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: cs.primary,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: Colors.black.withOpacity(0.78),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _submitButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: saving ? null : _submit, // ✅ logic เดิม
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary.withOpacity(0.95),
                cs.secondary.withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : const Text(
                    'ส่งแบบประเมิน',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // =========================
  // ✅ Logic เดิม (ไม่แตะ)
  // =========================

  Future<void> _submit() async {
    setState(() => saving = true);

    try {
      final safeAnswers = answers.map((e) => e ?? 0).toList();
      final cls = classifyPhq9(safeAnswers);

      final result = Phq9Result(
        uid: widget.user.uid,
        answers: safeAnswers,
        scoreTotal: safeAnswers.fold(0, (a, b) => a + b),
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

  void _showResultDialog(String risk) {
    String message;

    switch (risk) {
      case 'green':
        message = 'สถานะ/อาการของคุณอยู่ในระดับสีเขียว\nปลอดภัย';
        break;

      case 'yellow':
        message = 'สถานะ/อาการของคุณอยู่ในระดับสีเหลือง\nขั้นตอนถัดไปให้ทำแบบทดสอบเชิงลึก\nแทบด้านล่างสีเหลืองในหน้าแรก';
        break;

      case 'red':
        message = 'สถานะ/อาการของคุณอยู่ในระดับสีแดง\nขั้นตอนถัดไปให้ทำแบบทดสอบเชิงลึก\nแทบด้านล่างสีเหลืองในหน้าแรก';
        break;

      default:
        message = 'ไม่สามารถประเมินผลได้';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('ผลการประเมิน'),
        content: Text(message),
        actions: [
          ElevatedButton(
            child: const Text('ตกลง'),
            onPressed: () async {
              Navigator.pop(context);

              await FirestoreService().updatePhq9Status(
                uid: widget.user.uid,
                riskLevel: risk,
              );

              if (widget.fromHome) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }
}