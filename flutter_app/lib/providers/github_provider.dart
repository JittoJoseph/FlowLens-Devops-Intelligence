import 'package:flutter/material.dart';
import '../models/repository.dart';
import '../services/api_service.dart';

enum GitHubConnectionStatus { disconnected, connecting, connected, error }

class GitHubProvider extends ChangeNotifier {
  GitHubConnectionStatus _status = GitHubConnectionStatus.disconnected;
  Repository? _selectedRepository;
  List<Repository> _repositories = [];
  String? _errorMessage;
  String? _username;
  String? _avatarUrl;
  bool _isLoading = false;
  bool _servicesHealthy = false;

  // Getters
  GitHubConnectionStatus get status => _status;
  Repository? get selectedRepository => _selectedRepository;
  List<Repository> get repositories => List.unmodifiable(_repositories);
  String? get errorMessage => _errorMessage;
  String? get username => _username;
  String? get avatarUrl => _avatarUrl;
  bool get isLoading => _isLoading;
  bool get servicesHealthy => _servicesHealthy;

  bool get isConnected => _status == GitHubConnectionStatus.connected;
  bool get isConnecting => _status == GitHubConnectionStatus.connecting;
  bool get hasError => _status == GitHubConnectionStatus.error;

  // Check services health in background
  Future<void> checkServicesHealth() async {
    _servicesHealthy = await ApiService.performHealthChecks();
    notifyListeners();
  }

  // Load repositories from API
  Future<void> loadRepositories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _repositories = await ApiService.getRepositories();
      _isLoading = false;
    } catch (e) {
      _errorMessage = 'Failed to load repositories: ${e.toString()}';
      _isLoading = false;
    }

    notifyListeners();
  }

  // Simulate GitHub connection (for demo purposes)
  Future<void> connectToGitHub() async {
    _status = GitHubConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      // First check if services are healthy
      if (!_servicesHealthy) {
        _status = GitHubConnectionStatus.error;
        _errorMessage =
            'Backend services are not available. Please try again later.';
        notifyListeners();
        return;
      }

      // Simulate connection delay
      await Future.delayed(const Duration(seconds: 1));

      // Load real repositories from API
      await loadRepositories();

      // Set connected state
      _username = 'DevOps-Malayalam';
      _avatarUrl = 'https://avatars.githubusercontent.com/u/example';
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
    _servicesHealthy = false;
    notifyListeners();
  }

  void selectRepository(Repository repository) {
    _selectedRepository = repository;
    notifyListeners();
  }
}
