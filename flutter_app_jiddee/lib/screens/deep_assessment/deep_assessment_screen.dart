import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import '../patient/appointment_screen.dart';
import '../../services/notification_service.dart';

class DeepAssessmentScreen extends StatefulWidget {
  final AppUser user;
  const DeepAssessmentScreen({super.key, required this.user});

  @override
  State<DeepAssessmentScreen> createState() => _DeepAssessmentScreenState();
}

class _DeepAssessmentScreenState extends State<DeepAssessmentScreen> {
  // =========================
  // ✅ Logic เดิม (ห้ามแตะ)
  // =========================
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

  /// ✅ กลุ่ม 2 “กลับคะแนน”
  final Set<int> _reverseItems = const {
    5, 6, 7, 8, 9, 10, 11, 12, 13, 25, 26, 27, 28,
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
  // Draft: Load / Save / Clear (เดิม)
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
          content: Text(
            'คุณตอบไว้แล้ว $answered/${_questions.length} ข้อ\nต้องการทำต่อหรือเริ่มใหม่?',
          ),
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
          _lastTouchedIndex = (idx is int)
              ? idx.clamp(0, _questions.length - 1)
              : 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                content: Text(
                  'โหลดคำตอบที่ค้างไว้แล้ว • ต่อได้ที่ข้อ ${_lastTouchedIndex + 1}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                duration: const Duration(seconds: 2),
              ),
            );
      } else {
        await _fs.clearDeepDraft(widget.user.uid);
        if (!mounted) return;
        setState(() {
          _answers = List<int>.filled(_questions.length, -1);
          _lastTouchedIndex = 0;
        });
      }
    } catch (_) {}
  }

  void _scheduleAutoSave({required int touchedIndex}) {
    _lastTouchedIndex = touchedIndex;

    if (_answeredCount == 0) return;

    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 650), () async {
      try {
        await _fs.saveDeepDraft(
          uid: widget.user.uid,
          answers: _answers,
          currentIndex: _lastTouchedIndex,
        );
      } catch (_) {}
    });
  }

  Future<void> _saveAndExit() async {
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('บันทึกแบบร่างแล้ว')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
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
      return false;
    }

    if (res == 'discard') return true;
    return false;
  }

  // =========================
  // ✅ UI ใหม่ (ตกแต่งเท่านั้น)
  // =========================
  static const String _mascotAsset = 'assets/images/jitdee_mascot.png';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final answered = _answeredCount;
    final total = _questions.length;

    return WillPopScope(
      onWillPop: () async => await _confirmExitIfDirty(),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('แบบสอบถามเชิงลึก (TMHI-55)'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.black.withOpacity(0.82),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final ok = await _confirmExitIfDirty();
              if (ok && mounted) Navigator.pop(context);
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton.icon(
                onPressed: _saving ? null : _saveAndExit,
                style: TextButton.styleFrom(
                  backgroundColor: cs.primary.withOpacity(0.10),
                  foregroundColor: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: const Icon(Icons.save_alt),
                label: const Text(
                  'บันทึกแล้วกลับ',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),

        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.secondary.withOpacity(0.25),
                cs.primary.withOpacity(0.12),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: _introCard(context, answered, total),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 104),
                    itemCount: _questions.length,
                    itemBuilder: (context, i) {
                      final qNo = i + 1;
                      final selected = _answers[i];

                      return _questionCard(
                        context: context,
                        index: i,
                        qNo: qNo,
                        title: _questions[i],
                        selected: selected,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: _submitBar(context, answered, total),
          ),
        ),
      ),
    );
  }

  Widget _introCard(BuildContext context, int answered, int total) {
  final cs = Theme.of(context).colorScheme;
  final progress = total == 0 ? 0.0 : answered / total;

  return Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: Colors.white.withOpacity(0.88),
      border: Border.all(color: Colors.black.withOpacity(0.05)),
      boxShadow: [
        BoxShadow(
          blurRadius: 14,
          offset: const Offset(0, 8),
          color: Colors.black.withOpacity(0.05),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // mascot small
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(_mascotAsset, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "ตอบแล้ว $answered / $total ข้อ",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                  color: Colors.black.withOpacity(0.82),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.black.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    cs.primary.withOpacity(0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // right actions
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Draft pill (ถ้าตอบแล้ว)
            if (answered > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF00B894).withOpacity(0.20),
                  ),
                ),
                child: const Text(
                  "Draft: ON",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Color(0xFF00B894),
                  ),
                ),
              ),
            const SizedBox(height: 6),

            // Help button (ดูคำอธิบาย 0–3)
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "วิธีให้คะแนน 0–3",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 10),
                        Text("0 = ไม่เลย"),
                        Text("1 = เล็กน้อย"),
                        Text("2 = มาก"),
                        Text("3 = มากที่สุด"),
                        SizedBox(height: 10),
                        Text(
                          "ตอบตามความรู้สึกของคุณในช่วงที่ผ่านมา",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cs.primary.withOpacity(0.18)),
                ),
                child: Icon(Icons.help_outline, color: cs.primary, size: 18),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _questionCard({
    required BuildContext context,
    required int index,
    required int qNo,
    required String title,
    required int selected,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.92),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  "$qNo",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.8,
                    height: 1.35,
                    color: Colors.black.withOpacity(0.82),
                  ),
                ),
              ),
              if (selected >= 0)
                Icon(
                  Icons.check_circle,
                  color: const Color(0xFF00B894).withOpacity(0.90),
                  size: 18,
                ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(4, (v) {
              final isOn = selected == v;

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _saving
                    ? null
                    : () {
                        setState(() => _answers[index] = v);
                        _scheduleAutoSave(touchedIndex: index);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isOn
                        ? cs.primary.withOpacity(0.14)
                        : Colors.black.withOpacity(0.03),
                    border: Border.all(
                      color: isOn
                          ? cs.primary.withOpacity(0.35)
                          : Colors.black.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOn) ...[
                        Icon(Icons.check, size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        "$v",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isOn ? cs.primary : Colors.black.withOpacity(0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _submitBar(BuildContext context, int answered, int total) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        onPressed: _canSubmit ? _submit : null, // ✅ logic เดิม
        child: Ink(
          decoration: BoxDecoration(
            gradient: _canSubmit
                ? LinearGradient(
                    colors: [
                      cs.primary.withOpacity(0.95),
                      cs.secondary.withOpacity(0.95),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.10),
                    ],
                  ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    "ส่งคำตอบ ($answered/$total)",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required Color color,
    required Color border,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  // =========================
  // Scoring (เดิม)
  // =========================

  int _calculateScore() {
    int total = 0;

    for (int i = 0; i < _answers.length; i++) {
      final qNo = i + 1;
      final ans = _answers[i]; // 0..3
      final base = ans + 1; // 1..4

      final isReverse = _reverseItems.contains(qNo);
      final score = isReverse ? (5 - base) : base;

      total += score;
    }
    return total; // 55..220
  }

  ({String level, String label, Color color}) _interpret(int score) {
    if (score >= 179) {
      return (level: 'green', label: 'Good (ดี)', color: Colors.green);
    }
    if (score >= 158) {
      return (level: 'yellow', label: 'Fair (ปานกลาง)', color: Colors.orange);
    }
    return (level: 'red', label: 'Poor (ควรเฝ้าระวัง)', color: Colors.red);
  }

  // =========================
  // Submit (เดิม)
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

      if (result.level == 'yellow') {
        NotificationService.instance.scheduleDeepReminderTest(
          uid: widget.user.uid,
        );
      }

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ส่งคำตอบไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}