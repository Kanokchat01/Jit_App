import 'package:flutter/material.dart';
import '../../models/risk_level.dart';

class ResultScreen extends StatelessWidget {
  final String riskLevel;
  final int totalScore;

  const ResultScreen({
    super.key,
    required this.riskLevel,
    required this.totalScore,
  });

  static const String _mascotAsset = 'assets/images/jitdee_mascot.png';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final RiskLevel? risk = riskFromString(riskLevel);

    final Color mainColor = risk?.color ?? cs.primary;
    final String label = risk?.label ?? "ไม่สามารถประเมินได้";

    return Scaffold(
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              children: [
                _topBar(context),
                const SizedBox(height: 24),

                _resultHero(context, mainColor, label),
                const SizedBox(height: 28),

                _scoreCard(context, mainColor),
                const Spacer(),

                _doneButton(context, mainColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =======================
  // 🔹 TOP BAR
  // =======================

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 6),
        const Text(
          "ผลการประเมิน",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // =======================
  // 🔹 HERO RESULT CARD
  // =======================

  Widget _resultHero(BuildContext context, Color mainColor, String label) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white.withOpacity(0.90),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 14),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // bubble background
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mainColor.withOpacity(0.18),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Mascot + floating shadow
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // shadow
                      Positioned(
                        bottom: 6,
                        child: Container(
                          width: 90,
                          height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            gradient: RadialGradient(
                              colors: [
                                mainColor.withOpacity(0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: mainColor.withOpacity(0.10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            _mascotAsset,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text(
                    "ระดับความเสี่ยง",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.black.withOpacity(0.65),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: mainColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: mainColor.withOpacity(0.35),
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: mainColor,
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

  // =======================
  // 🔹 SCORE CARD
  // =======================

  Widget _scoreCard(BuildContext context, Color mainColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: mainColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.analytics_outlined, color: mainColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "คะแนนรวมของคุณ",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: Colors.black.withOpacity(0.82),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: mainColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              "$totalScore",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: mainColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =======================
  // 🔹 DONE BUTTON
  // =======================

  Widget _doneButton(BuildContext context, Color mainColor) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: () {
          Navigator.popUntil(context, (route) => route.isFirst);
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                mainColor.withOpacity(0.95),
                mainColor.withOpacity(0.70),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Center(
            child: Text(
              "กลับสู่หน้าหลัก",
              style: TextStyle(
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
}