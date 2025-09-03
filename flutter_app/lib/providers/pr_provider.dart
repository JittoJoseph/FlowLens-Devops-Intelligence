import 'package:flutter/material.dart';
import '../models/pull_request.dart';
import '../models/ai_insight.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class PRProvider extends ChangeNotifier {
  List<PullRequest> _pullRequests = [];
  final Map<int, AIInsight> _insights = {};
  bool _isLoading = false;
  String? _errorMessage;
  PullRequest? _selectedPR;
  String? _currentRepositoryId;
  bool _isInitialized =
      false; // Flag to prevent notifications during initialization

  // WebSocket service
  final WebSocketService _webSocketService = WebSocketService();

  // Getters
  List<PullRequest> get pullRequests => List.unmodifiable(_pullRequests);
  Map<int, AIInsight> get insights => Map.unmodifiable(_insights);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  PullRequest? get selectedPR => _selectedPR;
  String? get currentRepositoryId => _currentRepositoryId;

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

  void _handlePRStateUpdate(PRStateUpdate update) {
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

      final updatedPR = _pullRequests[prIndex].copyWith(
        status: convertState(update.state),
        updatedAt: DateTime.now(),
      );

      _pullRequests[prIndex] = updatedPR;
      notifyListeners();
    }
  }

  // Load pull requests from API (replaces the old loadPullRequests)
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
        _insights[insight.prNumber] = insight;
      }
    } catch (e) {
      // Don't fail the whole operation if insights fail
    }
  }

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
    super.dispose();
  }
}
