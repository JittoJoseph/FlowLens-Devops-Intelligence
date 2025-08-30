import 'package:flutter/material.dart';
import '../models/pull_request.dart';
import '../models/ai_insight.dart';

class PRProvider extends ChangeNotifier {
  List<PullRequest> _pullRequests = [];
  Map<int, AIInsight> _insights = {};
  bool _isLoading = false;
  String? _errorMessage;
  PullRequest? _selectedPR;

  // Getters
  List<PullRequest> get pullRequests => List.unmodifiable(_pullRequests);
  Map<int, AIInsight> get insights => Map.unmodifiable(_insights);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  PullRequest? get selectedPR => _selectedPR;

  AIInsight? getInsightForPR(int prNumber) {
    return _insights[prNumber];
  }

  List<PullRequest> get openPRs {
    return _pullRequests
        .where(
          (pr) => pr.status != PRStatus.merged && pr.status != PRStatus.closed,
        )
        .toList();
  }

  List<PullRequest> get recentPRs {
    final sortedPRs = [..._pullRequests];
    sortedPRs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sortedPRs.take(10).toList();
  }

  // Load demo data
  Future<void> loadPullRequests() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));

      _pullRequests = _generateDemoPRs();
      _insights = _generateDemoInsights();
      _isLoading = false;
    } catch (e) {
      _errorMessage = 'Failed to load pull requests: ${e.toString()}';
      _isLoading = false;
    }

    notifyListeners();
  }

  void selectPR(PullRequest pr) {
    _selectedPR = pr;
    notifyListeners();
  }

  void updatePRStatus(int prNumber, PRStatus newStatus) {
    final index = _pullRequests.indexWhere((pr) => pr.number == prNumber);
    if (index != -1) {
      _pullRequests[index] = _pullRequests[index].copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  List<PullRequest> _generateDemoPRs() {
    final now = DateTime.now();
    return [
      PullRequest(
        number: 123,
        title: 'Add AI-powered risk assessment for PR workflow',
        description:
            'Implement Gemini API integration for automated code analysis and risk scoring',
        author: 'jitto',
        authorAvatar: 'https://avatars.githubusercontent.com/u/jitto',
        commitSha: 'a1b2c3d4e5f6',
        repositoryName: 'mission-control',
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(minutes: 15)),
        status: PRStatus.building,
        filesChanged: [
          'lib/services/ai_service.dart',
          'lib/models/ai_insight.dart',
          'README.md',
        ],
        additions: 245,
        deletions: 12,
        branchName: 'feature/ai-risk-assessment',
      ),
      PullRequest(
        number: 122,
        title: 'Update Flutter dependencies to latest versions',
        description:
            'Bump Flutter SDK and core dependencies for better performance and security',
        author: 'sarah_dev',
        authorAvatar: 'https://avatars.githubusercontent.com/u/sarah_dev',
        commitSha: 'b2c3d4e5f6g7',
        repositoryName: 'mission-control',
        createdAt: now.subtract(const Duration(hours: 6)),
        updatedAt: now.subtract(const Duration(hours: 1)),
        status: PRStatus.approved,
        filesChanged: ['pubspec.yaml', 'pubspec.lock'],
        additions: 8,
        deletions: 8,
        branchName: 'chore/update-dependencies',
      ),
      PullRequest(
        number: 121,
        title: 'Fix WebSocket connection handling in real-time updates',
        description:
            'Resolve connection drops and implement proper reconnection logic',
        author: 'alex_ops',
        authorAvatar: 'https://avatars.githubusercontent.com/u/alex_ops',
        commitSha: 'c3d4e5f6g7h8',
        repositoryName: 'mission-control',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 4)),
        status: PRStatus.merged,
        filesChanged: [
          'lib/services/websocket_service.dart',
          'lib/providers/realtime_provider.dart',
        ],
        additions: 67,
        deletions: 34,
        branchName: 'fix/websocket-reconnection',
      ),
      PullRequest(
        number: 120,
        title: 'Implement dark mode theme for better UX',
        description:
            'Add dark theme support with proper color schemes and animations',
        author: 'ui_designer',
        authorAvatar: 'https://avatars.githubusercontent.com/u/ui_designer',
        commitSha: 'd4e5f6g7h8i9',
        repositoryName: 'mission-control',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
        status: PRStatus.buildPassed,
        filesChanged: [
          'lib/config/app_theme.dart',
          'lib/providers/theme_provider.dart',
        ],
        additions: 156,
        deletions: 23,
        branchName: 'feature/dark-mode',
      ),
      PullRequest(
        number: 119,
        title: 'Add comprehensive unit tests for PR workflow',
        description:
            'Increase test coverage for critical PR tracking functionality',
        author: 'test_engineer',
        authorAvatar: 'https://avatars.githubusercontent.com/u/test_engineer',
        commitSha: 'e5f6g7h8i9j0',
        repositoryName: 'mission-control',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 2)),
        status: PRStatus.pending,
        filesChanged: [
          'test/providers/pr_provider_test.dart',
          'test/services/api_service_test.dart',
        ],
        additions: 234,
        deletions: 5,
        branchName: 'test/pr-workflow-coverage',
      ),
    ];
  }

  Map<int, AIInsight> _generateDemoInsights() {
    final now = DateTime.now();
    return {
      123: AIInsight(
        id: 'insight_123',
        prNumber: 123,
        commitSha: 'a1b2c3d4e5f6',
        riskLevel: RiskLevel.medium,
        summary: 'AI integration with external API requires careful review',
        recommendation:
            'Ensure proper error handling and rate limiting for Gemini API calls',
        createdAt: now.subtract(const Duration(hours: 3)),
        keyChanges: [
          'New AI service integration',
          'External API dependency',
          'Data model changes',
        ],
        confidenceScore: 0.85,
      ),
      122: AIInsight(
        id: 'insight_122',
        prNumber: 122,
        commitSha: 'b2c3d4e5f6g7',
        riskLevel: RiskLevel.low,
        summary: 'Routine dependency updates with minimal risk',
        recommendation: 'Safe to merge after automated tests pass',
        createdAt: now.subtract(const Duration(hours: 6)),
        keyChanges: ['Dependency version bumps', 'Security patches'],
        confidenceScore: 0.95,
      ),
      121: AIInsight(
        id: 'insight_121',
        prNumber: 121,
        commitSha: 'c3d4e5f6g7h8',
        riskLevel: RiskLevel.high,
        summary: 'Critical WebSocket changes affect real-time functionality',
        recommendation: 'Thorough testing required for reconnection scenarios',
        createdAt: now.subtract(const Duration(days: 1)),
        keyChanges: [
          'WebSocket connection logic',
          'Error handling changes',
          'State management updates',
        ],
        confidenceScore: 0.78,
      ),
      120: AIInsight(
        id: 'insight_120',
        prNumber: 120,
        commitSha: 'd4e5f6g7h8i9',
        riskLevel: RiskLevel.low,
        summary: 'UI theme changes with good test coverage',
        recommendation: 'Review for accessibility compliance before merge',
        createdAt: now.subtract(const Duration(days: 2)),
        keyChanges: [
          'Theme configuration',
          'Color scheme updates',
          'Animation improvements',
        ],
        confidenceScore: 0.92,
      ),
      119: AIInsight(
        id: 'insight_119',
        prNumber: 119,
        commitSha: 'e5f6g7h8i9j0',
        riskLevel: RiskLevel.low,
        summary: 'Test coverage improvements enhance code quality',
        recommendation:
            'Excellent addition - improves overall project reliability',
        createdAt: now.subtract(const Duration(days: 3)),
        keyChanges: [
          'Unit test additions',
          'Mock implementations',
          'Test utilities',
        ],
        confidenceScore: 0.98,
      ),
    };
  }

  void refresh() {
    loadPullRequests();
  }
}
