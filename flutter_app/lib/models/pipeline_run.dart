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
  /// This method removes duplicates, orders chronologically, and ensures logical flow
  List<PipelineHistoryEvent> get cleanedHistory {
    if (history.isEmpty) return [];

    // First, sort all events by timestamp
    final sortedEvents = List<PipelineHistoryEvent>.from(history);
    sortedEvents.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final cleanedEvents = <PipelineHistoryEvent>[];
    final seenStates = <String, String>{}; // field -> latest value

    // Process events to remove unnecessary duplicates and create logical flow
    for (final event in sortedEvents) {
      final key = event.field;
      final lastValue = seenStates[key];

      // Skip if we've already seen this exact state transition
      if (lastValue == event.value) continue;

      // For build events, ensure logical sequence
      if (key == 'status_build') {
        // If we're going from building to buildPassed, keep both
        // If we're seeing buildPassed after buildPassed, skip
        if (event.value == 'buildPassed' && lastValue == 'buildPassed') {
          continue;
        }

        // If we see building after buildPassed, it's a new build cycle
        if (event.value == 'building' && lastValue == 'buildPassed') {
          // This is a new build, keep it
        }
      }

      cleanedEvents.add(event);
      seenStates[key] = event.value;
    }

    // Ensure we have a logical minimum set of events
    final finalEvents = <PipelineHistoryEvent>[];

    // Add PR opened event if not present (infer from creation)
    if (!cleanedEvents.any(
      (e) => e.field == 'status_pr' && e.value == 'opened',
    )) {
      finalEvents.add(
        PipelineHistoryEvent(
          timestamp: createdAt,
          field: 'status_pr',
          value: 'opened',
          meta: {'inferred': true},
        ),
      );
    }

    // Add the cleaned events
    finalEvents.addAll(cleanedEvents);

    // Remove any trailing duplicate states and limit to recent events
    final recentEvents = finalEvents.length > 6
        ? finalEvents.sublist(finalEvents.length - 6)
        : finalEvents;

    return recentEvents;
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
      case 'buildPassed':
        return 'Build Passed';
      case 'buildFailed':
        return 'Build Failed';
      case 'building':
        return 'Building';
      case 'approved':
        return 'Approved';
      case 'merged':
        return 'Merged';
      case 'pending':
        return 'Pending';
      default:
        return value;
    }
  }

  String get eventDescription {
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
