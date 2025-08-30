import 'package:flutter/foundation.dart';

@immutable
class AIInsight {
  final String id;
  final int prNumber;
  final String commitSha;
  final RiskLevel riskLevel;
  final String summary;
  final String recommendation;
  final DateTime createdAt;
  final List<String> keyChanges;
  final double confidenceScore;

  const AIInsight({
    required this.id,
    required this.prNumber,
    required this.commitSha,
    required this.riskLevel,
    required this.summary,
    required this.recommendation,
    required this.createdAt,
    required this.keyChanges,
    this.confidenceScore = 0.0,
  });

  AIInsight copyWith({
    String? id,
    int? prNumber,
    String? commitSha,
    RiskLevel? riskLevel,
    String? summary,
    String? recommendation,
    DateTime? createdAt,
    List<String>? keyChanges,
    double? confidenceScore,
  }) {
    return AIInsight(
      id: id ?? this.id,
      prNumber: prNumber ?? this.prNumber,
      commitSha: commitSha ?? this.commitSha,
      riskLevel: riskLevel ?? this.riskLevel,
      summary: summary ?? this.summary,
      recommendation: recommendation ?? this.recommendation,
      createdAt: createdAt ?? this.createdAt,
      keyChanges: keyChanges ?? this.keyChanges,
      confidenceScore: confidenceScore ?? this.confidenceScore,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prNumber': prNumber,
      'commitSha': commitSha,
      'riskLevel': riskLevel.name,
      'summary': summary,
      'recommendation': recommendation,
      'createdAt': createdAt.toIso8601String(),
      'keyChanges': keyChanges,
      'confidenceScore': confidenceScore,
    };
  }

  factory AIInsight.fromJson(Map<String, dynamic> json) {
    return AIInsight(
      id: json['id'] as String,
      prNumber: json['prNumber'] as int,
      commitSha: json['commitSha'] as String,
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.name == json['riskLevel'],
      ),
      summary: json['summary'] as String,
      recommendation: json['recommendation'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      keyChanges: List<String>.from(json['keyChanges'] as List),
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIInsight && other.id == id && other.prNumber == prNumber;
  }

  @override
  int get hashCode => Object.hash(id, prNumber);

  @override
  String toString() {
    return 'AIInsight(id: $id, prNumber: $prNumber, riskLevel: $riskLevel, summary: $summary)';
  }
}

enum RiskLevel {
  low,
  medium,
  high;

  String get displayName {
    switch (this) {
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.medium:
        return 'Medium Risk';
      case RiskLevel.high:
        return 'High Risk';
    }
  }

  String get description {
    switch (this) {
      case RiskLevel.low:
        return 'Changes are low-impact and well-tested';
      case RiskLevel.medium:
        return 'Changes require careful review';
      case RiskLevel.high:
        return 'Changes have potential for significant impact';
    }
  }
}
