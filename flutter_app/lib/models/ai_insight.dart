import 'package:flutter/foundation.dart';

@immutable
class AIInsight {
  final String id;
  final String? repositoryId; // Repository UUID
  final int prNumber;
  final String commitSha;
  final String author;
  final String avatarUrl;
  final RiskLevel riskLevel;
  final String summary;
  final String recommendation;
  final DateTime createdAt;
  final List<String> keyChanges;
  final double confidenceScore;

  const AIInsight({
    required this.id,
    this.repositoryId,
    required this.prNumber,
    required this.commitSha,
    required this.author,
    required this.avatarUrl,
    required this.riskLevel,
    required this.summary,
    required this.recommendation,
    required this.createdAt,
    required this.keyChanges,
    this.confidenceScore = 0.0,
  });

  AIInsight copyWith({
    String? id,
    String? repositoryId,
    int? prNumber,
    String? commitSha,
    String? author,
    String? avatarUrl,
    RiskLevel? riskLevel,
    String? summary,
    String? recommendation,
    DateTime? createdAt,
    List<String>? keyChanges,
    double? confidenceScore,
  }) {
    return AIInsight(
      id: id ?? this.id,
      repositoryId: repositoryId ?? this.repositoryId,
      prNumber: prNumber ?? this.prNumber,
      commitSha: commitSha ?? this.commitSha,
      author: author ?? this.author,
      avatarUrl: avatarUrl ?? this.avatarUrl,
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
      'repositoryId': repositoryId,
      'prNumber': prNumber,
      'commitSha': commitSha,
      'author': author,
      'avatarUrl': avatarUrl,
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
      repositoryId: json['repositoryId'] as String?,
      prNumber: json['prNumber'] as int,
      commitSha: json['commitSha'] as String,
      author: json['author'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
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

  // Factory constructor for API response format
  factory AIInsight.fromApiJson(Map<String, dynamic> json) {
    RiskLevel convertRiskLevel(String risk) {
      switch (risk.toLowerCase()) {
        case 'low':
          return RiskLevel.low;
        case 'medium':
          return RiskLevel.medium;
        case 'high':
          return RiskLevel.high;
        default:
          return RiskLevel.medium;
      }
    }

    // Helper to safely parse datetime
    DateTime parseDateTime(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) {
        return DateTime.now();
      }
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return DateTime.now();
      }
    }

    return AIInsight(
      id: json['id'] as String? ?? '',
      repositoryId: json['repo_id'] as String?,
      prNumber: (json['pr_number'] as num?)?.toInt() ?? 0,
      commitSha: json['commit_sha'] as String? ?? '',
      author: json['author'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      riskLevel: convertRiskLevel(json['risk_level'] as String? ?? 'medium'),
      summary: json['summary'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
      createdAt: parseDateTime(json['created_at'] as String?),
      keyChanges: json['keyChanges'] != null
          ? List<String>.from(json['keyChanges'] as List)
          : [],
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
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
