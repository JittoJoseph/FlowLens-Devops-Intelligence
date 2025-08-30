import 'package:flutter/material.dart';
import '../models/repository.dart';

enum GitHubConnectionStatus { disconnected, connecting, connected, error }

class GitHubProvider extends ChangeNotifier {
  GitHubConnectionStatus _status = GitHubConnectionStatus.disconnected;
  Repository? _selectedRepository;
  List<Repository> _repositories = [];
  String? _errorMessage;
  String? _username;
  String? _avatarUrl;

  // Getters
  GitHubConnectionStatus get status => _status;
  Repository? get selectedRepository => _selectedRepository;
  List<Repository> get repositories => List.unmodifiable(_repositories);
  String? get errorMessage => _errorMessage;
  String? get username => _username;
  String? get avatarUrl => _avatarUrl;

  bool get isConnected => _status == GitHubConnectionStatus.connected;
  bool get isConnecting => _status == GitHubConnectionStatus.connecting;
  bool get hasError => _status == GitHubConnectionStatus.error;

  // Simulate GitHub connection (for demo purposes)
  Future<void> connectToGitHub() async {
    _status = GitHubConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 2));

      // Simulate successful connection with demo data
      _username = 'DevOps-Malayalam';
      _avatarUrl = 'https://avatars.githubusercontent.com/u/example';
      _repositories = _generateDemoRepositories();
      _selectedRepository = _repositories.first;
      _status = GitHubConnectionStatus.connected;
    } catch (e) {
      _status = GitHubConnectionStatus.error;
      _errorMessage = 'Failed to connect to GitHub: ${e.toString()}';
    }

    notifyListeners();
  }

  void disconnect() {
    _status = GitHubConnectionStatus.disconnected;
    _selectedRepository = null;
    _repositories.clear();
    _errorMessage = null;
    _username = null;
    _avatarUrl = null;
    notifyListeners();
  }

  void selectRepository(Repository repository) {
    _selectedRepository = repository;
    notifyListeners();
  }

  List<Repository> _generateDemoRepositories() {
    final now = DateTime.now();
    return [
      Repository(
        name: 'mission-control',
        fullName: 'DevOps-Malayalam/mission-control',
        description:
            'AI-Powered DevOps Workflow Visualizer with real-time insights',
        owner: 'DevOps-Malayalam',
        ownerAvatar: 'https://avatars.githubusercontent.com/u/example1',
        isPrivate: false,
        defaultBranch: 'main',
        openPRs: 5,
        totalPRs: 23,
        lastActivity: now.subtract(const Duration(hours: 2)),
        languages: ['Dart', 'Python', 'JavaScript'],
        stars: 42,
        forks: 8,
      ),
      Repository(
        name: 'devops-toolkit',
        fullName: 'DevOps-Malayalam/devops-toolkit',
        description:
            'A comprehensive toolkit for DevOps automation and monitoring',
        owner: 'DevOps-Malayalam',
        ownerAvatar: 'https://avatars.githubusercontent.com/u/example1',
        isPrivate: true,
        defaultBranch: 'main',
        openPRs: 3,
        totalPRs: 15,
        lastActivity: now.subtract(const Duration(days: 1)),
        languages: ['Python', 'Shell', 'Docker'],
        stars: 18,
        forks: 3,
      ),
      Repository(
        name: 'flutter-analytics',
        fullName: 'DevOps-Malayalam/flutter-analytics',
        description: 'Real-time analytics dashboard built with Flutter',
        owner: 'DevOps-Malayalam',
        ownerAvatar: 'https://avatars.githubusercontent.com/u/example1',
        isPrivate: false,
        defaultBranch: 'develop',
        openPRs: 2,
        totalPRs: 8,
        lastActivity: now.subtract(const Duration(hours: 6)),
        languages: ['Dart', 'TypeScript'],
        stars: 12,
        forks: 2,
      ),
    ];
  }
}
