import 'package:flutter/material.dart';

enum RiskLevel { green, yellow, red }

RiskLevel? riskFromString(String? s) {
  switch (s) {
    case 'green':
      return RiskLevel.green;
    case 'yellow':
      return RiskLevel.yellow;
    case 'red':
      return RiskLevel.red;
    default:
      return null;
  }
}

String riskToString(RiskLevel r) {
  switch (r) {
    case RiskLevel.green:
      return 'green';
    case RiskLevel.yellow:
      return 'yellow';
    case RiskLevel.red:
      return 'red';
  }
}

extension RiskLevelUI on RiskLevel {
  Color get color {
    switch (this) {
      case RiskLevel.green:
        return Colors.green;
      case RiskLevel.yellow:
        return Colors.orange;
      case RiskLevel.red:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case RiskLevel.green:
        return Icons.check_circle;
      case RiskLevel.yellow:
        return Icons.warning;
      case RiskLevel.red:
        return Icons.error;
    }
  }

  String get label {
    switch (this) {
      case RiskLevel.green:
        return 'ความเสี่ยงต่ำ (สีเขียว)';
      case RiskLevel.yellow:
        return 'ควรติดตาม (สีเหลือง)';
      case RiskLevel.red:
        return 'ความเสี่ยงสูง (สีแดง)';
    }
  }
}
