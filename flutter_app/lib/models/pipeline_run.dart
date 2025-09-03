import 'dart:convert';

class PipelineRun {
  final String id;
  final String repoId;
  final int prNumber;
  final String commitSha;
  final String author;
  final String avatarUrl;
  final String title;
  final String statusPr;
  final String statusBuild;
  final String statusApproval;
  final String statusMerge;
  final List<PipelineHistoryEvent> history;
  final bool processed;
  final DateTime createdAt;
  final DateTime updatedAt;

  PipelineRun({
    required this.id,
    required this.repoId,
    required this.prNumber,
    required this.commitSha,
    required this.author,
    required this.avatarUrl,
    required this.title,
    required this.statusPr,
    required this.statusBuild,
    required this.statusApproval,
    required this.statusMerge,
    required this.history,
    required this.processed,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PipelineRun.fromApiJson(Map<String, dynamic> json) {
    List<PipelineHistoryEvent> parseHistory(String historyJson) {
      try {
        final List<dynamic> historyList = jsonDecode(historyJson);
        return historyList
            .map((item) => PipelineHistoryEvent.fromJson(item))
            .toList();
      } catch (e) {
        return [];
      }
    }

    return PipelineRun(
      id: json['id'] ?? '',
      repoId: json['repo_id'] ?? '',
      prNumber: (json['pr_number'] is int)
          ? json['pr_number']
          : int.tryParse(json['pr_number']?.toString() ?? '0') ?? 0,
      commitSha: json['commit_sha'] ?? '',
      author: json['author'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      title: json['title'] ?? '',
      statusPr: json['status_pr'] ?? '',
      statusBuild: json['status_build'] ?? '',
      statusApproval: json['status_approval'] ?? '',
      statusMerge: json['status_merge'] ?? '',
      history: parseHistory(json['history'] ?? '[]'),
      processed: json['processed'] == true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  String get shortCommitSha {
    return commitSha.length > 7 ? commitSha.substring(0, 7) : commitSha;
  }

  String get overallStatus {
    if (statusMerge == 'merged') return 'merged';
    if (statusBuild == 'buildFailed') return 'failed';
    if (statusBuild == 'building') return 'building';
    if (statusBuild == 'buildPassed' && statusApproval == 'approved') {
      return 'ready';
    }
    if (statusBuild == 'buildPassed') return 'passed';
    return 'pending';
  }

  Duration get totalDuration {
    if (history.isEmpty) return Duration.zero;

    final firstEvent = history.first;
    final lastEvent = history.last;

    return lastEvent.timestamp.difference(firstEvent.timestamp);
  }

  PipelineHistoryEvent? get latestEvent {
    if (history.isEmpty) return null;
    return history.last;
  }

  /// Returns a cleaned and properly ordered list of pipeline events
  List<PipelineHistoryEvent> get cleanedHistory {
    if (history.isEmpty) return [];

    final sortedEvents = List<PipelineHistoryEvent>.from(history);
    sortedEvents.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final stateProgression = <PipelineHistoryEvent>[];
    String? lastOverallState;

    // Add PR opened event if not present
    if (!sortedEvents.any(
      (e) => e.field == 'status_pr' && e.value == 'opened',
    )) {
      stateProgression.add(
        PipelineHistoryEvent(
          timestamp: createdAt,
          field: 'overall_state',
          value: 'opened',
          meta: {'inferred': true},
        ),
      );
      lastOverallState = 'opened';
    }

    for (final event in sortedEvents) {
      final overallState = _getOverallStateFromEvent(event);

      // Skip duplicates and backwards progressions
      if (overallState == lastOverallState ||
          _isBackwardsProgression(lastOverallState, overallState)) {
        continue;
      }

      stateProgression.add(
        PipelineHistoryEvent(
          timestamp: event.timestamp,
          field: 'overall_state',
          value: overallState,
          meta: event.meta,
        ),
      );
      lastOverallState = overallState;
    }

    return stateProgression.length > 8
        ? stateProgression.sublist(stateProgression.length - 8)
        : stateProgression;
  }

  String _getOverallStateFromEvent(PipelineHistoryEvent event) {
    if (event.field == 'status_pr') return event.value;
    if (event.field == 'status_build') return event.value;
    if (event.field == 'status_approval') return event.value;
    if (event.field == 'status_merge') return event.value;
    return event.value;
  }

  bool _isBackwardsProgression(String? fromState, String toState) {
    if (fromState == null) return false;

    const statePriority = {
      'opened': 1,
      'updated': 1,
      'building': 2,
      'buildPassed': 3,
      'buildFailed': 3,
      'approved': 4,
      'rejected': 4,
      'merged': 5,
      'closed': 5,
    };

    final fromPriority = statePriority[fromState] ?? 1;
    final toPriority = statePriority[toState] ?? 1;

    // Don't allow building after buildPassed/Failed (prevents messy data)
    if ((fromState == 'buildPassed' || fromState == 'buildFailed') &&
        toState == 'building') {
      return true;
    }

    return toPriority < fromPriority;
  }
}

class PipelineHistoryEvent {
  final DateTime timestamp;
  final String field;
  final String value;
  final Map<String, dynamic> meta;

  PipelineHistoryEvent({
    required this.timestamp,
    required this.field,
    required this.value,
    required this.meta,
  });

  factory PipelineHistoryEvent.fromJson(Map<String, dynamic> json) {
    return PipelineHistoryEvent(
      timestamp: DateTime.tryParse(json['at'] ?? '') ?? DateTime.now(),
      field: json['field'] ?? '',
      value: json['value'] ?? '',
      meta: Map<String, dynamic>.from(json['meta'] ?? {}),
    );
  }

  String get displayValue {
    switch (value) {
      case 'opened':
        return 'Opened';
      case 'updated':
        return 'Updated';
      case 'buildPassed':
        return 'Build Passed';
      case 'buildFailed':
        return 'Build Failed';
      case 'building':
        return 'Building';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'merged':
        return 'Merged';
      case 'closed':
        return 'Closed';
      case 'pending':
        return 'Pending';
      default:
        return value;
    }
  }

  String get eventDescription {
    // Handle normalized overall_state events
    if (field == 'overall_state') {
      switch (value) {
        case 'opened':
          return 'Pull Request Opened';
        case 'updated':
          return 'Pull Request Updated';
        case 'building':
          return 'Build Started';
        case 'buildPassed':
          return 'Build Passed';
        case 'buildFailed':
          return 'Build Failed';
        case 'approved':
          return 'Code Review Approved';
        case 'rejected':
          return 'Changes Requested';
        case 'merged':
          return 'Pull Request Merged';
        case 'closed':
          return 'Pull Request Closed';
        default:
          return 'Status Updated';
      }
    }

    // Handle field-specific events
    switch (field) {
      case 'status_build':
        switch (value) {
          case 'building':
            return 'Build Started';
          case 'buildPassed':
            return 'Build Passed';
          case 'buildFailed':
            return 'Build Failed';
          default:
            return 'Build Status Updated';
        }
      case 'status_approval':
        switch (value) {
          case 'approved':
            return 'Code Review Approved';
          case 'pending':
            return 'Awaiting Review';
          case 'rejected':
            return 'Changes Requested';
          default:
            return 'Review Status Updated';
        }
      case 'status_merge':
        switch (value) {
          case 'merged':
            return 'Pull Request Merged';
          case 'pending':
            return 'Ready to Merge';
          default:
            return 'Merge Status Updated';
        }
      case 'status_pr':
        switch (value) {
          case 'opened':
            return 'Pull Request Opened';
          case 'closed':
            return 'Pull Request Closed';
          default:
            return 'PR Status Updated';
        }
      default:
        return '$field: $displayValue';
    }
  }
}
