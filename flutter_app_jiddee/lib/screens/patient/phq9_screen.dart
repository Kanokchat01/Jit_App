import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/app_user.dart';
import '../../models/phq9_result.dart';
import '../../services/firestore_service.dart';
import 'result_screen.dart';

class Phq9Screen extends StatefulWidget {
  final AppUser user;
  const Phq9Screen({super.key, required this.user});

  @override
  State<Phq9Screen> createState() => _Phq9ScreenState();
}

class _Phq9ScreenState extends State<Phq9Screen> {
  final questions = const [
    '1) Little interest or pleasure in doing things',
    '2) Feeling down, depressed, or hopeless',
    '3) Trouble falling or staying asleep, or sleeping too much',
    '4) Feeling tired or having little energy',
    '5) Poor appetite or overeating',
    '6) Feeling bad about yourself — or that you are a failure',
    '7) Trouble concentrating on things',
    '8) Moving/speaking slowly or being fidgety/restless',
    '9) Thoughts that you would be better off dead or hurting yourself',
  ];

  final options = const [
    (0, 'Not at all'),
    (1, 'Several days'),
    (2, 'More than half the days'),
    (3, 'Nearly every day'),
  ];

  final answers = List<int>.filled(9, 0);
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final total = answers.fold<int>(0, (p, c) => p + c);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Total score: $total', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (int i = 0; i < questions.length; i++) ...[
          Text(questions[i], style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final (val, label) in options)
            RadioListTile<int>(
              value: val,
              groupValue: answers[i],
              onChanged: saving ? null : (v) => setState(() => answers[i] = v ?? 0),
              title: Text(label),
              dense: true,
            ),
          const Divider(height: 24),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: saving ? null : _submit,
            child: saving
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit'),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final total = answers.fold<int>(0, (p, c) => p + c);
      final cls = classifyPhq9(answers);

      final result = Phq9Result(
        uid: uid,
        answers: List<int>.from(answers),
        scoreTotal: total,
        severity: cls.severity,
        riskLevel: cls.riskLevel,
        createdAt: DateTime.now(),
      );

      await FirestoreService().savePhq9Result(result);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
