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

extension PRStatusPriority on PRStatus {
  /// Priority level for PR status (higher number = higher priority)
  /// Matches API service priority: opened < building < buildPassed/Failed < approved < merged/closed
  int get priority {
    switch (this) {
      case PRStatus.pending: // maps to 'opened' in API
        return 1;
      case PRStatus.building:
        return 2;
      case PRStatus.buildPassed:
        return 3;
      case PRStatus.buildFailed:
        return 3; // Same priority as buildPassed
      case PRStatus.approved:
        return 4;
      case PRStatus.merged:
        return 5;
      case PRStatus.closed:
        return 5; // Same priority as merged (final states)
    }
  }

  /// Determines if this status should override another status based on priority
  bool shouldOverride(PRStatus other) {
    // Never override with the same status (prevent duplicates)
    if (this == other) return false;

    // Final states (merged/closed) should never be overridden
    if (other == PRStatus.merged || other == PRStatus.closed) {
      return this == PRStatus.merged || this == PRStatus.closed;
    }

    // Approved state should only be overridden by final states
    if (other == PRStatus.approved) {
      return priority >= other.priority;
    }

    // Build completed states should NOT be overridden by building (prevents messy data)
    if (other == PRStatus.buildPassed || other == PRStatus.buildFailed) {
      // Don't allow building to override completed builds (prevents backwards progression)
      if (this == PRStatus.building) return false;
      // Only allow higher priority states (approved, merged, closed)
      return priority > other.priority;
    }

    // For other cases, use simple priority comparison
    return priority >= other.priority;
  }
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
    // Helper function to convert individual state values
    PRStatus convertStateValue(String state) {
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

    // Sophisticated status determination with priority-based logic
    PRStatus determineStatus(
      String basicState,
      List<dynamic>? history,
      bool merged,
    ) {
      // If merged, that's the final status
      if (merged || basicState.toLowerCase() == 'merged') {
        return PRStatus.merged;
      }

      // If closed but not merged
      if (basicState.toLowerCase() == 'closed') {
        return PRStatus.closed;
      }

      // Extract latest meaningful status from history
      String? latestMeaningfulState;
      if (history != null && history.isNotEmpty) {
        // Find the most recent non-open state
        for (int i = history.length - 1; i >= 0; i--) {
          final event = history[i];
          if (event is Map<String, dynamic>) {
            final stateName = event['state_name'] as String?;
            if (stateName != null &&
                stateName != 'open' &&
                stateName != 'opened') {
              latestMeaningfulState = stateName;
              break;
            }
          }
        }
      }

      // Priority-based status determination logic:
      // 1. merged/closed (already handled above)
      // 2. approved
      // 3. buildPassed/buildFailed/building
      // 4. opened/pending

      if (latestMeaningfulState != null) {
        // Check for approval states first (higher priority)
        if (latestMeaningfulState == 'approved') {
          return PRStatus.approved;
        }

        // Then check for build states
        if (latestMeaningfulState == 'buildPassed') {
          return PRStatus.buildPassed;
        }
        if (latestMeaningfulState == 'buildFailed') {
          return PRStatus.buildFailed;
        }
        if (latestMeaningfulState == 'building') {
          return PRStatus.building;
        }
      }

      // Fallback to basic state conversion
      return convertStateValue(basicState);
    }

    return PullRequest(
      id: json['id'] as String?,
      repositoryId:
          json['repositoryId'] as String? ?? json['repo_id'] as String?,
      number: json['number'] as int? ?? json['pr_number'] as int,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      author: json['author'] as String,
      authorAvatar:
          json['authorAvatar'] as String? ??
          json['author_avatar'] as String? ??
          '',
      commitSha:
          json['commitSha'] as String? ?? json['commit_sha'] as String? ?? '',
      repositoryName:
          json['repositoryName'] as String? ??
          json['repository_name'] as String? ??
          '',
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? json['created_at'] as String,
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] as String? ?? json['updated_at'] as String,
      ),
      status: determineStatus(
        json['status'] as String? ?? json['state'] as String? ?? 'pending',
        json['history'] as List<dynamic>?,
        json['merged'] as bool? ?? false,
      ),
      filesChanged: json['changed_files'] != null
          ? [
              for (int i = 0; i < (json['changed_files'] as int); i++)
                'File ${i + 1}',
            ]
          : [], // Generate placeholder file names based on count
      additions: json['additions'] as int? ?? 0,
      deletions: json['deletions'] as int? ?? 0,
      branchName:
          json['branchName'] as String? ?? json['branch_name'] as String? ?? '',
      isDraft: json['isDraft'] as bool? ?? json['is_draft'] as bool? ?? false,
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
