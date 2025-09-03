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
  final String? id; // UUID from API
  final String? repositoryId; // Repository UUID
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
    this.id,
    this.repositoryId,
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
    String? id,
    String? repositoryId,
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
      id: id ?? this.id,
      repositoryId: repositoryId ?? this.repositoryId,
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
      'id': id,
      'repositoryId': repositoryId,
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
      id: json['id'] as String?,
      repositoryId: json['repositoryId'] as String?,
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

  // Factory constructor for API response format
  factory PullRequest.fromApiJson(Map<String, dynamic> json) {
    // Convert API state to our PRStatus enum
    PRStatus convertState(String state) {
      switch (state.toLowerCase()) {
        case 'open':
        case 'opened':
          return PRStatus.pending;
        case 'building':
          return PRStatus.building;
        case 'buildpassed':
          return PRStatus.buildPassed;
        case 'buildfailed':
          return PRStatus.buildFailed;
        case 'approved':
          return PRStatus.approved;
        case 'merged':
          return PRStatus.merged;
        case 'closed':
          return PRStatus.closed;
        default:
          return PRStatus.pending;
      }
    }

    return PullRequest(
      id: json['id'] as String?,
      repositoryId: json['repo_id'] as String?,
      number: json['pr_number'] as int,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      author: json['author'] as String,
      authorAvatar: json['author_avatar'] as String? ?? '',
      commitSha: json['commit_sha'] as String? ?? '',
      repositoryName: '', // Will need to be populated from repository data
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      status: convertState(json['state'] as String? ?? 'pending'),
      filesChanged: json['changed_files'] != null
          ? [
              for (int i = 0; i < (json['changed_files'] as int); i++)
                'File ${i + 1}',
            ]
          : [], // Generate placeholder file names based on count
      additions: json['additions'] as int? ?? 0,
      deletions: json['deletions'] as int? ?? 0,
      branchName: json['branch_name'] as String? ?? '',
      isDraft: json['is_draft'] as bool? ?? false,
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
