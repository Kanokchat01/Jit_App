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
  final double neutralPreferMargin;

  /// ✅ ใหม่: ถ้า topScore ยังไม่สูงมาก (ก้ำกึ่ง) ให้เอียงไป neutral
  final double neutralLowConfidenceGate;

  /// ✅ sad ต้องนำ neutral อย่างน้อยค่านี้ ถึงจะแสดง sad
  final double sadNeutralMinGap;

  /// ✅ ต้องนำ emotion เดิมค่านี้ ถึงจะเปลี่ยน (ลดการกระโดด)
  final double stickyMargin;

  int samples = 0;
  double avgConfidence = 0.0;

  final Map<String, double> _ema = {};
  EmotionAggCurrent? _current;

  double _sumConfidence = 0.0;

  /// ✅ นับจำนวนครั้งจริงของแต่ละอารมณ์ (ไม่ decay)
  final Map<String, int> _rawCounts = {};

  EmotionAggCurrent? get current => _current;

  EmotionAggregator({
    required this.labels,
    this.confidenceThreshold = 0.03,
    this.maxSamples = 120,
    this.emaAlpha = 0.22,
    this.minMargin = 0.10,
    this.neutralPreferMargin = 0.08,
    this.neutralLowConfidenceGate = 0.18,
    this.sadNeutralMinGap = 0.10,
    this.stickyMargin = 0.05,
  }) {
    reset();
  }

  void reset() {
    samples = 0;
    avgConfidence = 0.0;
    _sumConfidence = 0.0;

    _ema.clear();
    _rawCounts.clear();
    for (final l in labels) {
      _ema[l] = 0.0;
      _rawCounts[l] = 0;
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

    // ✅ นับจำนวนครั้งจริง
    _rawCounts[label] = (_rawCounts[label] ?? 0) + 1;

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

  /// ✅ รับ score ของทุก emotion จาก model output (แม่นยำกว่า addSample)
  void addSampleAll(Map<String, double> scores) {
    if (scores.isEmpty) return;

    // ✅ นับจำนวนครั้งจริง: หา label ที่ score สูงสุด
    String topLabel = '';
    double topConf = 0.0;
    for (final entry in scores.entries) {
      if (entry.value > topConf) {
        topConf = entry.value;
        topLabel = entry.key;
      }
    }
    if (topLabel.isNotEmpty && topConf >= confidenceThreshold) {
      _rawCounts[topLabel] = (_rawCounts[topLabel] ?? 0) + 1;
    }

    samples = min(samples + 1, maxSamples);
    _sumConfidence += topConf;
    avgConfidence = _sumConfidence / max(1, samples);

    for (final k in _ema.keys) {
      final prev = _ema[k] ?? 0.0;
      final target = scores[k] ?? 0.0;
      _ema[k] = prev * (1 - emaAlpha) + target * emaAlpha;
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

  /// ✅ นับจำนวนดิบ
  Map<String, int> get rawCounts => Map<String, int>.from(_rawCounts);

  /// ✅ คิด % จากจำนวนครั้งจริง (ไม่ decay เหมือน EMA)
  Map<String, double> summaryCountPercent() {
    int total = 0;
    for (final v in _rawCounts.values) {
      total += v;
    }
    if (total <= 0) return {for (final l in labels) l: 0.0};
    return {
      for (final l in labels)
        l: ((_rawCounts[l] ?? 0) / total) * 100.0,
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

    // ✅ sad-neutral disambiguation
    final disambiguated = _disambiguateSadNeutral(bestL: bestL, bestV: bestV);
    if (disambiguated != null) {
      _current = EmotionAggCurrent(disambiguated, _ema[disambiguated] ?? bestV);
      return;
    }

    // กติกาเดิม: ต้องชนะขาด
    if ((bestV - secondV) < minMargin) return;

    // ✅ Sticky: ถ้ามี emotion เดิมอยู่แล้ว ต้องนำ margin เพิ่ม ถึงจะเปลี่ยน
    if (_current != null && _current!.label != bestL) {
      final currentEma = _ema[_current!.label] ?? 0.0;
      if ((bestV - currentEma) < stickyMargin) return;
    }

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

  /// ✅ sad ต้องนำ neutral ชัดเจน ถึงจะยืนยันว่า sad จริง
  String? _disambiguateSadNeutral({
    required String bestL,
    required double bestV,
  }) {
    if (bestL != 'sad') return null;
    if (!labels.contains('neutral')) return null;

    final neutralV = _ema['neutral'] ?? 0.0;
    final sadV = _ema['sad'] ?? 0.0;

    // ถ้า sad นำ neutral ไม่ถึง sadNeutralMinGap → เลือก neutral แทน
    if ((sadV - neutralV) < sadNeutralMinGap) {
      return 'neutral';
    }

    return null;
  }

  // =========================
  // ✅ Happiness Score
  // =========================

  /// น้ำหนักอารมณ์ (expert-recommended for mental health screening)
  static const Map<String, double> emotionWeights = {
    'angry': -2.0,
    'fear': -1.5,
    'sad': -2.0,
    'neutral': 0.5,
    'happy': 2.0,
  };

  /// คำนวณ Happiness Score จาก count-based %
  /// Range: -2.0 ถึง +2.0
  double happinessScore() {
    final pct = summaryCountPercent();
    double score = 0.0;
    for (final entry in emotionWeights.entries) {
      score += (pct[entry.key] ?? 0.0) * entry.value;
    }
    return score / 100.0;
  }

  /// ตีความ Happiness Score เป็น 4 ระดับ
  /// good (≥+0.5), normal (0~+0.49), monitor (-0.49~-0.01), warning (≤-0.5)
  String happinessLevel() {
    final s = happinessScore();
    if (s >= 0.5) return 'good';
    if (s >= 0.0) return 'normal';
    if (s > -0.5) return 'monitor';
    return 'warning';
  }
}