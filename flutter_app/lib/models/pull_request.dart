import 'package:flutter/foundation.dart';

enum PRStatus {
  pending,
  building,
  buildPassed,
  buildFailed,
  approved,
  merged,
  closed,
}

@immutable
class PullRequest {
  final int number;
  final String title;
  final String description;
  final String author;
  final String authorAvatar;
  final String commitSha;
  final String repositoryName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PRStatus status;
  final List<String> filesChanged;
  final int additions;
  final int deletions;
  final String branchName;
  final bool isDraft;

  const PullRequest({
    required this.number,
    required this.title,
    required this.description,
    required this.author,
    required this.authorAvatar,
    required this.commitSha,
    required this.repositoryName,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.filesChanged,
    required this.additions,
    required this.deletions,
    required this.branchName,
    this.isDraft = false,
  });

  PullRequest copyWith({
    int? number,
    String? title,
    String? description,
    String? author,
    String? authorAvatar,
    String? commitSha,
    String? repositoryName,
    DateTime? createdAt,
    DateTime? updatedAt,
    PRStatus? status,
    List<String>? filesChanged,
    int? additions,
    int? deletions,
    String? branchName,
    bool? isDraft,
  }) {
    return PullRequest(
      number: number ?? this.number,
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      commitSha: commitSha ?? this.commitSha,
      repositoryName: repositoryName ?? this.repositoryName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      filesChanged: filesChanged ?? this.filesChanged,
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
      branchName: branchName ?? this.branchName,
      isDraft: isDraft ?? this.isDraft,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'title': title,
      'description': description,
      'author': author,
      'authorAvatar': authorAvatar,
      'commitSha': commitSha,
      'repositoryName': repositoryName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status.name,
      'filesChanged': filesChanged,
      'additions': additions,
      'deletions': deletions,
      'branchName': branchName,
      'isDraft': isDraft,
    };
  }

  factory PullRequest.fromJson(Map<String, dynamic> json) {
    return PullRequest(
      number: json['number'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      author: json['author'] as String,
      authorAvatar: json['authorAvatar'] as String,
      commitSha: json['commitSha'] as String,
      repositoryName: json['repositoryName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      status: PRStatus.values.firstWhere((e) => e.name == json['status']),
      filesChanged: List<String>.from(json['filesChanged'] as List),
      additions: json['additions'] as int,
      deletions: json['deletions'] as int,
      branchName: json['branchName'] as String,
      isDraft: json['isDraft'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PullRequest &&
        other.number == number &&
        other.repositoryName == repositoryName;
  }

  @override
  int get hashCode => Object.hash(number, repositoryName);

  @override
  String toString() {
    return 'PullRequest(number: $number, title: $title, author: $author, status: $status)';
  }
}
