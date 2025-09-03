import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pull_request.dart';
import '../models/ai_insight.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class PRProvider extends ChangeNotifier {
  List<PullRequest> _pullRequests = [];
  final Map<String, AIInsight> _insights = {}; // Changed to use composite key
  bool _isLoading = false;
  bool _isFetchingNewPR = false; // New indicator for background fetching
  String? _errorMessage;
  PullRequest? _selectedPR;
  String? _currentRepositoryId;
  bool _isInitialized =
      false; // Flag to prevent notifications during initialization

  // Stream controller for new PR notifications
  final _newPRController = StreamController<PullRequest>.broadcast();

  // WebSocket service
  final WebSocketService _webSocketService = WebSocketService();

  // Helper function to create a composite key for insights
  String _getInsightKey(String? repositoryId, int prNumber) {
    return '${repositoryId ?? 'unknown'}_$prNumber';
  }

  // Getters
  List<PullRequest> get pullRequests => List.unmodifiable(_pullRequests);
  Map<int, AIInsight> get insights => Map.unmodifiable(_insights);
  bool get isLoading => _isLoading;
  bool get isFetchingNewPR =>
      _isFetchingNewPR; // Getter for background fetching indicator
  String? get errorMessage => _errorMessage;
  PullRequest? get selectedPR => _selectedPR;
  String? get currentRepositoryId => _currentRepositoryId;

  // Stream for new PR notifications
  Stream<PullRequest> get newPRStream => _newPRController.stream;

  PRProvider() {
    // Initialize WebSocket after the first frame to avoid notifications during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebSocket();
      _isInitialized = true;
    });
  }

  void _initializeWebSocket() {
    _webSocketService.connect();
    _webSocketService.prStateUpdates.listen((update) {
      _handlePRStateUpdate(update);
    });
  }

  void _handlePRStateUpdate(PRStateUpdate update) async {
    // Don't notify during initialization to avoid setState during build
    if (!_isInitialized) return;

    // Find and update the PR if it exists in current list
    final prIndex = _pullRequests.indexWhere(
      (pr) =>
          pr.repositoryId == update.repositoryId &&
          pr.number == update.prNumber,
    );

    if (prIndex != -1) {
      // Convert state to PRStatus
      PRStatus convertState(String state) {
        switch (state.toLowerCase()) {
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

      final newStatus = convertState(update.state);
      final currentPR = _pullRequests[prIndex];

      // Only update status if the new status has higher or equal priority
      final shouldUpdate = newStatus.shouldOverride(currentPR.status);

      // Debug logging to track status updates with reasoning
      final reason = !shouldUpdate
          ? (newStatus == currentPR.status ? "DUPLICATE" : "LOWER_PRIORITY")
          : "ACCEPTED";
      debugPrint(
        '📊 PR #${update.prNumber}: ${currentPR.status.name} -> ${newStatus.name} ($reason)',
      );

      if (shouldUpdate) {
        final updatedPR = currentPR.copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
        );
        _pullRequests[prIndex] = updatedPR;
        notifyListeners();
      }
    } else {
      // PR not found in current list - this might be a new PR
      // Only fetch if it's a newly opened PR and we're viewing the same repository
      if (update.state.toLowerCase() == 'opened' &&
          (_currentRepositoryId == null ||
              _currentRepositoryId == update.repositoryId)) {
        await _fetchNewPR(update.repositoryId, update.prNumber);
      }
    }
  }

  // Fetch a specific new PR and add it to the list
  Future<void> _fetchNewPR(String repositoryId, int prNumber) async {
    if (_isFetchingNewPR) return; // Prevent multiple simultaneous fetches

    _isFetchingNewPR = true;
    notifyListeners(); // Show loading indicator

    try {
      // First, try to fetch just this specific PR using the insights endpoint
      // as a way to check if the PR exists and get basic info
      final insights = await ApiService.getInsightsForPR(
        prNumber,
        repositoryId: repositoryId,
      );

      // If we get insights, fetch the full PR data
      final allPRs = await ApiService.getPullRequests(
        repositoryId: repositoryId,
      );

      // Find the specific PR
      final newPR = allPRs.where((pr) => pr.number == prNumber).firstOrNull;

      if (newPR == null) {
        return; // PR not found, might be in a different repository
      }

      // Check if we already have this PR (double-check)
      final exists = _pullRequests.any(
        (pr) => pr.repositoryId == repositoryId && pr.number == prNumber,
      );

      if (!exists) {
        // Add the new PR to the beginning of the list for visibility
        _pullRequests.insert(0, newPR);

        // Add insights if available
        if (insights.isNotEmpty) {
          _insights[_getInsightKey(repositoryId, prNumber)] = insights.first;
        }

        // Emit new PR event for UI notifications
        _newPRController.add(newPR);
      }
    } catch (e) {
      // Failed to fetch new PR - this is not critical
      // The user can still refresh manually if needed
      // In a production app, you might want to log this
    } finally {
      _isFetchingNewPR = false;
      notifyListeners(); // Hide loading indicator and update UI
    }
  }

  // Load pull requests from API
  Future<void> loadPullRequests({String? repositoryId}) async {
    _isLoading = true;
    _errorMessage = null;
    _currentRepositoryId = repositoryId;
    notifyListeners();

    try {
      _pullRequests = await ApiService.getPullRequests(
        repositoryId: repositoryId,
      );
      await _loadInsights(repositoryId: repositoryId);
      _isLoading = false;
    } catch (e) {
      _errorMessage = 'Failed to load pull requests: ${e.toString()}';
      _isLoading = false;
    }

    notifyListeners();
  }

  // Load AI insights
  Future<void> _loadInsights({String? repositoryId}) async {
    try {
      final insightsList = await ApiService.getInsights(
        repositoryId: repositoryId,
      );
      _insights.clear();
      for (final insight in insightsList) {
        final key = _getInsightKey(insight.repositoryId, insight.prNumber);
        _insights[key] = insight;
      }
    } catch (e) {
      // Don't fail the whole operation if insights fail
    }
  }

  AIInsight? getInsightForPR(int prNumber, {String? repositoryId}) {
    final key = _getInsightKey(repositoryId, prNumber);
    return _insights[key];
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

  void refresh({String? repositoryId}) {
    loadPullRequests(repositoryId: repositoryId);
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    _newPRController.close();
    super.dispose();
  }
}
