import 'dart:math';

class EmotionAggCurrent {
  final String label;
  final double confidence;
  EmotionAggCurrent(this.label, this.confidence);
}

class EmotionAggregator {
  final List<String> labels;

  /// YOLO score มักต่ำ → ใช้ต่ำ ๆ
  final double confidenceThreshold;

  final int maxSamples;
  final double emaAlpha;

  /// margin ขั้นต่ำระหว่างอันดับ 1 และ 2
  final double minMargin;

  /// ✅ ใหม่: ทำให้ "neutral" ชนะในเคสก้ำกึ่ง
  /// ถ้า top1 เป็น sad/fear/angry แต่ neutral ตามมาใกล้ ๆ ภายใน margin นี้ → บังคับ neutral
  final double neutralPreferMargin;

  /// ✅ ใหม่: ถ้า topScore ยังไม่สูงมาก (ก้ำกึ่ง) ให้เอียงไป neutral
  /// (ช่วยแก้เคสหน้านิ่งแต่โมเดลโยนไป sad)
  final double neutralLowConfidenceGate;

  int samples = 0;
  double avgConfidence = 0.0;

  final Map<String, double> _ema = {};
  EmotionAggCurrent? _current;

  double _sumConfidence = 0.0;

  EmotionAggCurrent? get current => _current;

  EmotionAggregator({
    required this.labels,
    this.confidenceThreshold = 0.03,
    this.maxSamples = 120,
    this.emaAlpha = 0.22,
    this.minMargin = 0.10,

    // ✅ ปรับ 2 ค่านี้เพื่อดัน neutral
    this.neutralPreferMargin = 0.08,      // ใกล้กันไม่เกินนี้ → neutral ชนะ
    this.neutralLowConfidenceGate = 0.18, // top EMA ยังต่ำ → ถือว่าไม่ชัด → neutral
  }) {
    reset();
  }

  void reset() {
    samples = 0;
    avgConfidence = 0.0;
    _sumConfidence = 0.0;

    _ema.clear();
    for (final l in labels) {
      _ema[l] = 0.0;
    }
    _current = null;
  }

  void addSample(String label, double conf) {
    if (!_ema.containsKey(label)) return;
    if (conf.isNaN || conf.isInfinite) return;

    // ต่ำกว่า threshold: decay เฉย ๆ
    if (conf < confidenceThreshold) {
      _decay();
      _updateCurrent();
      return;
    }

    samples = min(samples + 1, maxSamples);
    _sumConfidence += conf;
    avgConfidence = _sumConfidence / max(1, samples);

    // EMA update
    for (final k in _ema.keys) {
      final v = _ema[k] ?? 0.0;
      final target = (k == label) ? conf : 0.0;
      _ema[k] = v * (1 - emaAlpha) + target * emaAlpha;
    }

    _updateCurrent();
  }

  Map<String, double> summaryEma() => Map<String, double>.from(_ema);

  Map<String, double> summaryEmaPercent() {
    final m = Map<String, double>.from(_ema);
    double sum = 0.0;
    for (final v in m.values) {
      sum += max(0.0, v);
    }
    if (sum <= 0) return {for (final l in labels) l: 0.0};

    return {
      for (final l in labels) l: (max(0.0, (m[l] ?? 0.0)) / sum) * 100.0
    };
  }

  String dominantEmotion() => _current?.label ?? '';
  double dominantScore() => _current?.confidence ?? 0.0;

  void _decay() {
    for (final k in _ema.keys) {
      final v = _ema[k] ?? 0.0;
      _ema[k] = v * (1 - emaAlpha);
    }
  }

  void _updateCurrent() {
    // หา top1 / top2
    String bestL = labels.first;
    double bestV = -1;
    String secondL = labels.first;
    double secondV = -1;

    for (final l in labels) {
      final v = _ema[l] ?? 0.0;
      if (v > bestV) {
        secondV = bestV;
        secondL = bestL;
        bestV = v;
        bestL = l;
      } else if (v > secondV) {
        secondV = v;
        secondL = l;
      }
    }

    if (bestV < confidenceThreshold) return;

    // ✅ ใช้กติกา neutral ก่อน
    final forced = _preferNeutralIfAmbiguous(
      bestL: bestL,
      bestV: bestV,
      secondL: secondL,
      secondV: secondV,
    );
    if (forced != null) {
      _current = EmotionAggCurrent(forced, _ema[forced] ?? bestV);
      return;
    }

    // กติกาเดิม: ต้องชนะขาด
    if ((bestV - secondV) < minMargin) return;

    _current = EmotionAggCurrent(bestL, bestV);
  }

  /// ✅ บังคับ neutral เฉพาะตอน “ก้ำกึ่ง”
  String? _preferNeutralIfAmbiguous({
    required String bestL,
    required double bestV,
    required String secondL,
    required double secondV,
  }) {
    if (!labels.contains('neutral')) return null;

    final neutralV = _ema['neutral'] ?? 0.0;

    // 1) ถ้า top score ยังต่ำ (ไม่ชัด) และ neutral ไม่ได้ต่ำมาก → ให้ neutral
    if (bestV < neutralLowConfidenceGate && neutralV >= confidenceThreshold) {
      return 'neutral';
    }

    // 2) ถ้าโมเดลชอบโยนหน้านิ่งไป sad/fear/angry และ neutral ใกล้ ๆ → ให้ neutral
    final negativeSet = {'sad', 'fear', 'angry'};
    if (negativeSet.contains(bestL)) {
      // neutral เป็นอันดับ 2 หรือ 3 ก็ได้ ขอแค่ตามมาใกล้
      if ((bestV - neutralV).abs() <= neutralPreferMargin) {
        return 'neutral';
      }
      // หรือ neutral เป็นอันดับ 2 แบบสูสีมาก
      if (secondL == 'neutral' && (bestV - secondV) < (minMargin * 0.7)) {
        return 'neutral';
      }
    }

    return null;
  }
}