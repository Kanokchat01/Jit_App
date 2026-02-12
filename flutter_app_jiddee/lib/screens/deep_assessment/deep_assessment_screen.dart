import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import '../patient/appointment_screen.dart';

class DeepAssessmentScreen extends StatefulWidget {
  final AppUser user;
  const DeepAssessmentScreen({super.key, required this.user});

  @override
  State<DeepAssessmentScreen> createState() => _DeepAssessmentScreenState();
}

class _DeepAssessmentScreenState extends State<DeepAssessmentScreen> {
  final _fs = FirestoreService();

  bool _saving = false;

  /// -1 = ยังไม่ตอบ, 0..3 = คำตอบ
  late List<int> _answers;

  /// ใช้จำ “ข้อสุดท้ายที่แก้” เพื่อบันทึก currentIndex ใน draft
  int _lastTouchedIndex = 0;

  /// debounce autosave
  Timer? _draftDebounce;

  // ✅ คำถาม TMHI-55 (ครบ 55 ข้อ)
  final List<String> _questions = const [
    'ท่านรู้สึกพึงพอใจในชีวิต',
    'ท่านรู้สึกสบายใจ',
    'ท่านรู้สึกสดชื่นเบิกบานใจ',
    'ท่านรู้สึกชีวิตของท่านมีความสุขสงบ (ความสงบสุขในจิตใจ)',
    'ท่านรู้สึกเบื่อหน่ายท้อแท้กับการดำเนินชีวิตประจำวัน',
    'ท่านรู้สึกผิดหวังในตัวเอง',
    'ท่านรู้สึกว่าชีวิตของท่านมีแต่ความทุกข์',
    'ท่านรู้สึกกังวลใจ',
    'ท่านรู้สึกเศร้าโดยไม่ทราบสาเหตุ',
    'ท่านรู้สึกโกรธหงุดหงิดง่ายโดยไม่ทราบสาเหตุ',
    'ท่านต้องไปรับการรักษาพยาบาลเสมอๆ เพื่อให้สามารถดำเนินชีวิตและทำงานได้',
    'ท่านเป็นโรคเรื้อรัง (เบาหวาน ความดันโลหิตสูง อัมพาต ลมชัก ฯลฯ) ในกรณีถ้ามีให้ระบุว่ามีความรุนแรงของโรคเล็กน้อยหรือมากตามอาการที่มี',
    'ท่านรู้สึกกังวลหรือทุกข์ทรมานใจเกี่ยวกับการเจ็บป่วยของท่าน',
    'ท่านพอใจต่อการผูกมิตรหรือเข้ากับบุคคลอื่น',
    'ท่านมีสัมพันธภาพที่ดีกับเพื่อนบ้าน',
    'ท่านมีสัมพันธภาพที่ดีกับเพื่อนร่วมงาน (ทำงานร่วมกับคนอื่น)',
    'ท่านคิดว่าท่านมีความเป็นอยู่และฐานะทางสังคม ตามที่ท่านได้คาดหวังไว้',
    'ท่านรู้สึกประสบความสำเร็จและความก้าวหน้าในชีวิต',
    'ท่านรู้สึกพึงพอใจกับฐานะความเป็นอยู่ของท่าน',
    'ท่านเห็นว่าปัญหาส่วนใหญ่เป็นสิ่งที่แก้ไขได้',
    'ท่านสามารถทำใจยอมรับได้สำหรับปัญหาที่ยากจะแก้ไข (เมื่อมีปัญหา)',
    'ท่านมั่นใจว่าจะสามารถควบคุมอารมณ์ได้ เมื่อมีเหตุการณ์คับขันหรือร้ายแรงเกิดขึ้น',
    'ท่านมั่นใจที่จะเผชิญกับเหตุการณ์ร้ายแรงที่เกิดขึ้นในชีวิต',
    'ท่านแก้ปัญหาที่ขัดแย้งได้',
    'ท่านจะรู้สึกหงุดหงิด ถ้าสิ่งต่างๆ ไม่เป็นไปตามที่คาดหวัง',
    'ท่านหงุดหงิดโมโหง่ายถ้าท่านถูกวิพากษ์วิจารณ์',
    'ท่านรู้สึกหงุดหงิด กังวลใจกับเรื่องเล็กๆน้อยๆ ที่เกิดขึ้นเสมอ',
    'ท่านรู้สึกกังวลใจกับเรื่องทุกเรื่องที่มากระทบตัวท่าน',
    'ท่านรู้สึกยินดีกับความสำเร็จของคนอื่น',
    'ท่านรู้สึกเห็นใจเมื่อผู้อื่นมีทุกข์',
    'ท่านรู้สึกเป็นสุขในการช่วยเหลือผู้อื่นเมื่อมีโอกาส',
    'ท่านให้ความช่วยเหลือแก่ผู้อื่นเมื่อมีโอกาส',
    'ท่านเสียสละแรงกายหรือทรัพย์สินเพื่อประโยชน์ส่วนรวมโดยไม่หวังผลตอบแทน',
    'หากมีสถานการณ์ที่คับขันเสี่ยงภัย ท่านพร้อมที่จะให้ความช่วยเหลือร่วมกับผู้อื่น',
    'ท่านพึงพอใจกับความสามารถของตนเอง',
    'ท่านรู้สึกภูมิใจในตนเอง',
    'ท่านรู้สึกว่าท่านมีคุณค่าต่อครอบครัว',
    'ท่านมีสิ่งยึดเหนี่ยวสูงสุดในจิตใจที่ทำให้จิตใจมั่นคงในการดำเนินชีวิต',
    'ท่านมีความเชื่อมั่นว่าเมื่อเผชิญกับความยุ่งยากท่านมีสิ่งยึดเหนี่ยวสูงสุดในจิตใจ',
    'ท่านเคยประสบกับความยุ่งยากและสิ่งยึดเหนี่ยวสูงสุดในจิตใจช่วยให้ท่านผ่านพ้นไปได้',
    'ท่านต้องการทำบางสิ่งที่ใหม่ในทางที่ดีขึ้นกว่าที่เป็นอยู่เดิม',
    'ท่านมีความสุขกับการริเริ่มงานใหม่ๆ และมุ่งมั่นที่จะทำให้สำเร็จ',
    'ท่านมีความกระตือรือร้นที่จะเรียนรู้สิ่งใหม่ๆ ในทางที่ดี',
    'ท่านมีเพื่อนหรือคนอื่นๆ ในสังคมคอยช่วยเหลือท่านในยามที่ต้องการ',
    'ท่านได้รับความช่วยเหลือตามที่ท่านต้องการจากเพื่อนหรือคนอื่นๆในสังคม',
    'ท่านรู้สึกมั่นคง ปลอดภัยเมื่ออยู่ในครอบครัว',
    'หากท่านป่วยหนัก ท่านเชื่อว่าครอบครัวจะดูแลท่านเป็นอย่างดี',
    'ท่านปรึกษาหรือขอความช่วยเหลือจากครอบครัวเสมอเมื่อท่านมีปัญหา',
    'สมาชิกในครอบครัวมีความรักและผูกพันต่อกัน',
    'ท่านมั่นใจว่าชุมชนที่ท่านอาศัยอยู่มีความปลอดภัยต่อท่าน',
    'ท่านรู้สึกมั่นคงปลอดภัยในทรัพย์สินเมื่ออาศัยอยู่ในชุมชนนี้',
    'มีหน่วยงานสาธารณสุขใกล้บ้านที่ท่านสามารถไปใช้บริการได้',
    'หน่วยงานสาธารณสุขใกล้บ้านสามารถไปให้บริการได้เมื่อท่านต้องการ',
    'เมื่อท่านหรือญาติเจ็บป่วยจะไช้บริการจากหน่วยงานสาธารณสุขใกล้บ้าน',
    'เมื่อท่านเดือดร้อนจะมีหน่วยงานในชุมชน(เช่น มูลนิธิ ชมรม สมาคม วัด สุเหร่า ฯลฯ) มาช่วยเหลือดูแลท่าน',
  ];

  /// ✅ กลุ่ม 2 “กลับคะแนน” ตามรูปที่คุณส่งมา:
  /// 5,6,7,8,9,10,11,12,13,25,26,27,28
  final Set<int> _reverseItems = const {
    5, 6, 7, 8, 9, 10, 11, 12, 13, 25, 26, 27, 28
  };

  @override
  void initState() {
    super.initState();
    _answers = List<int>.filled(_questions.length, -1);
    _loadDraftIfAny();
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    super.dispose();
  }

  int get _answeredCount => _answers.where((a) => a >= 0).length;
  bool get _canSubmit => _answeredCount == _questions.length && !_saving;

  // =========================
  // Draft: Load / Save / Clear
  // =========================

  Future<void> _loadDraftIfAny() async {
    try {
      final draft = await _fs.watchDeepDraft(widget.user.uid).first;

      if (!mounted) return;
      if (draft == null) return;

      final raw = draft['answers'];
      final idx = (draft['currentIndex'] ?? 0);

      if (raw is! List) return;

      final restored = raw.map((e) {
        if (e is int) return e;
        if (e is num) return e.toInt();
        return -1;
      }).toList();

      if (restored.length != _questions.length) return;

      final answered = restored.where((a) => a >= 0).length;
      if (answered == 0) return;

      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('พบแบบสอบถามที่ทำค้างไว้'),
          content: Text('คุณตอบไว้แล้ว $answered/${_questions.length} ข้อ\nต้องการทำต่อหรือเริ่มใหม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'new'),
              child: const Text('เริ่มใหม่'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'continue'),
              child: const Text('ทำต่อ'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (choice == 'continue') {
        setState(() {
          _answers = restored;
          _lastTouchedIndex = (idx is int) ? idx.clamp(0, _questions.length - 1) : 0;
        });

        // บอกผู้ใช้ว่าค้างไว้แถวไหน (เลื่อนเองได้)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดคำตอบที่ค้างไว้แล้ว • ต่อได้ที่ข้อ ${_lastTouchedIndex + 1}')),
        );
      } else {
        // เริ่มใหม่: เคลียร์ draft + reset answers
        await _fs.clearDeepDraft(widget.user.uid);
        if (!mounted) return;
        setState(() {
          _answers = List<int>.filled(_questions.length, -1);
          _lastTouchedIndex = 0;
        });
      }
    } catch (_) {
      // ไม่ต้องทำอะไร ปล่อยผ่าน
    }
  }

  void _scheduleAutoSave({required int touchedIndex}) {
    _lastTouchedIndex = touchedIndex;

    // ถ้ายังไม่ตอบเลย ไม่ต้องเซฟ
    if (_answeredCount == 0) return;

    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 650), () async {
      try {
        await _fs.saveDeepDraft(
          uid: widget.user.uid,
          answers: _answers,
          currentIndex: _lastTouchedIndex,
        );
      } catch (_) {
        // เงียบไว้ ไม่รบกวน UX
      }
    });
  }

  Future<void> _saveAndExit() async {
    // ถ้าไม่ตอบเลย ก็ออกได้เลย
    if (_answeredCount == 0) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);
    try {
      await _fs.saveDeepDraft(
        uid: widget.user.uid,
        answers: _answers,
        currentIndex: _lastTouchedIndex,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกแบบร่างแล้ว')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmExitIfDirty() async {
    if (_answeredCount == 0) return true;

    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ออกจากหน้าแบบสอบถาม?'),
        content: const Text('คุณทำแบบสอบถามค้างไว้ ต้องการบันทึกไว้ก่อนออกไหม'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('อยู่ต่อ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('ไม่บันทึก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (res == 'save') {
      await _saveAndExit();
      return false; // เรา pop เองแล้ว
    }

    if (res == 'discard') {
      // ไม่บันทึก: แต่อย่าเคลียร์ draft อัตโนมัติ เผื่อเขาตั้งใจเก็บ (ถ้าต้องการเคลียร์จริง ค่อยทำปุ่มเฉพาะ)
      return true;
    }

    return false;
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    final answered = _answeredCount;
    final total = _questions.length;

    return WillPopScope(
      onWillPop: () async {
        final ok = await _confirmExitIfDirty();
        return ok;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('แบบสอบถามเชิงลึก (TMHI-55)'),
          backgroundColor: Colors.orange,
          actions: [
            TextButton.icon(
              onPressed: _saving ? null : _saveAndExit,
              icon: const Icon(Icons.save_alt, color: Colors.white),
              label: const Text(
                'บันทึกแล้วกลับ',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'กรุณาตอบตามความรู้สึกของคุณในช่วงที่ผ่านมา',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      const Text('ให้คะแนน 0–3'),
                      const Text('0 = ไม่เลย • 1 = เล็กน้อย • 2 = มาก • 3 = มากที่สุด'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, size: 16),
                          const SizedBox(width: 6),
                          Text('ตอบแล้ว $answered / $total ข้อ'),
                          const Spacer(),
                          if (answered > 0)
                            Text(
                              'Draft: ON',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.orange.shade800,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: _questions.length,
                  itemBuilder: (context, i) {
                    final qNo = i + 1;
                    final selected = _answers[i];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.black.withOpacity(0.06)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'ข้อที่ $qNo',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const Spacer(),
                                if (selected >= 0)
                                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(_questions[i]),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              children: List.generate(4, (v) {
                                final isOn = selected == v;
                                return ChoiceChip(
                                  label: Text('$v'),
                                  selected: isOn,
                                  onSelected: (_) {
                                    setState(() => _answers[i] = v);
                                    _scheduleAutoSave(touchedIndex: i);
                                  },
                                  selectedColor: Colors.orange.withOpacity(0.25),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _canSubmit ? _submit : null,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text('ส่งคำตอบ ($answered/$total)'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // Scoring
  // =========================

  int _calculateScore() {
    int total = 0;

    for (int i = 0; i < _answers.length; i++) {
      final qNo = i + 1;
      final ans = _answers[i]; // 0..3
      final base = ans + 1; // 1..4

      // กลุ่ม 2 กลับคะแนน: 1..4 => 4..1
      final isReverse = _reverseItems.contains(qNo);
      final score = isReverse ? (5 - base) : base;

      total += score;
    }
    return total; // 55..220
  }

  ({String level, String label, Color color}) _interpret(int score) {
    // 179–220 Good, 158–178 Fair, <=157 Poor
    if (score >= 179) {
      return (level: 'green', label: 'Good (ดี)', color: Colors.green);
    }
    if (score >= 158) {
      return (level: 'yellow', label: 'Fair (ปานกลาง)', color: Colors.orange);
    }
    return (level: 'red', label: 'Poor (ควรเฝ้าระวัง)', color: Colors.red);
  }

  // =========================
  // Submit
  // =========================

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _saving = true);
    _draftDebounce?.cancel();

    try {
      final score = _calculateScore();
      final result = _interpret(score);

      await _fs.updateDeepAssessmentStatus(
        uid: widget.user.uid,
        deepRiskLevel: result.level,
        deepScore: score,
      );

      // ✅ ส่งจริงแล้ว → เคลียร์ draft
      await _fs.clearDeepDraft(widget.user.uid);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('ผลแบบสอบถามเชิงลึก (TMHI-55)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('คะแนนรวม: $score / 220'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: result.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ระดับ: ${result.label}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: result.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  result.level == 'red'
                      ? 'ระบบแนะนำให้ติดต่อแพทย์เพื่อประเมินเพิ่มเติม'
                      : 'คุณสามารถกลับไปหน้า Home เพื่อดูสถานะได้',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ตกลง'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      // ✅ Flow หลังส่ง
      if (result.level == 'red') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AppointmentScreen(user: widget.user),
          ),
        );
      } else {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ส่งคำตอบไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
