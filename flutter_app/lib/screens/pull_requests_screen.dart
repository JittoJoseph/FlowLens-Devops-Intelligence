import 'package:flutter/material.dart';
import '../config/premium_theme.dart';
import '../models/pull_request.dart';
import '../models/repository.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/modern_floating_action_button.dart';

class PullRequestsScreen extends StatefulWidget {
  const PullRequestsScreen({super.key});

  @override
  State<PullRequestsScreen> createState() => _PullRequestsScreenState();
}

class _PullRequestsScreenState extends State<PullRequestsScreen> {
  List<PullRequest> _pullRequests = [];
  List<Repository> _repositories = [];
  String? _selectedRepositoryId;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  bool _isLoading = false;
  String? _error;

  final List<String> _statusFilters = ['all', 'open', 'closed', 'merged'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repositories = await ApiService.getRepositories();
      final pullRequests = await ApiService.getPullRequests();

      setState(() {
        _repositories = repositories;
        _pullRequests = pullRequests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  List<PullRequest> get _filteredPullRequests {
    return _pullRequests.where((pr) {
      // Repository filter
      if (_selectedRepositoryId != null &&
          pr.repositoryId != _selectedRepositoryId) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!pr.title.toLowerCase().contains(query) &&
            !pr.author.toLowerCase().contains(query) &&
            !pr.number.toString().contains(query)) {
          return false;
        }
      }

      // Status filter
      if (_selectedStatus != 'all') {
        final prState = pr.status.name.toLowerCase();
        if (_selectedStatus == 'open' && prState != 'pending') return false;
        if (_selectedStatus == 'closed' && prState != 'closed') return false;
        if (_selectedStatus == 'merged' && prState != 'merged') return false;
      }

      return true;
    }).toList();
  }

  String _getRepositoryName(String? repoId) {
    if (repoId == null) return 'Unknown Repo';
    final repo = _repositories.firstWhere(
      (r) => r.id == repoId,
      orElse: () => Repository(
        id: '',
        name: 'Unknown',
        fullName: '',
        description: '',
        owner: '',
        ownerAvatar: '',
        isPrivate: false,
        defaultBranch: '',
        openPRs: 0,
        totalPRs: 0,
        lastActivity: DateTime.now(),
        languages: [],
        stars: 0,
        forks: 0,
      ),
    );
    return repo.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: const AppSidebar(),
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        elevation: 0,
        foregroundColor:
            AppTheme.textPrimaryColor, // This ensures the menu icon is visible
        iconTheme: IconThemeData(color: AppTheme.textPrimaryColor),
        title: Text(
          'Pull Requests',
          style: AppTheme.premiumHeadingStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: Icon(Icons.refresh, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [_buildFiltersSection(), _buildContent()]),
      ),
      floatingActionButton: const ModernFloatingActionButton(),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search pull requests...',
              prefixIcon: Icon(
                Icons.search,
                color: AppTheme.textSecondaryColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor),
              ),
              fillColor: AppTheme.backgroundColor,
              filled: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // Filters row
          LayoutBuilder(
            builder: (context, constraints) {
              // Use column layout for narrow screens
              if (constraints.maxWidth < 500) {
                return Column(
                  children: [
                    // Repository filter
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedRepositoryId,
                      decoration: InputDecoration(
                        labelText: 'Repository',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Repositories'),
                        ),
                        ..._repositories.map(
                          (repo) => DropdownMenuItem<String?>(
                            value: repo.id,
                            child: Text(repo.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedRepositoryId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Status filter
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _statusFilters
                          .map(
                            (status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(
                                status == 'all' ? 'All' : status.toUpperCase(),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value ?? 'all';
                        });
                      },
                    ),
                  ],
                );
              }

              // Use row layout for wider screens
              return Row(
                children: [
                  // Repository filter
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedRepositoryId,
                      decoration: InputDecoration(
                        labelText: 'Repository',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Repositories'),
                        ),
                        ..._repositories.map(
                          (repo) => DropdownMenuItem<String?>(
                            value: repo.id,
                            child: Text(repo.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedRepositoryId = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Status filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _statusFilters
                          .map(
                            (status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(
                                status == 'all' ? 'All' : status.toUpperCase(),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value ?? 'all';
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTheme.premiumBodyStyle.copyWith(
                color: AppTheme.errorColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final filteredPRs = _filteredPullRequests;

    if (filteredPRs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.merge_outlined,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No pull requests found',
              style: AppTheme.premiumHeadingStyle.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or search criteria',
              style: AppTheme.premiumBodyStyle.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: filteredPRs.map((pr) => _buildPullRequestCard(pr)).toList(),
      ),
    );
  }

  Widget _buildPullRequestCard(PullRequest pr) {
    final repoName = _getRepositoryName(pr.repositoryId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.dividerColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // TODO: Navigate to PR details
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // PR number and status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(pr.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getStatusColor(
                          pr.status,
                        ).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(pr.status),
                          size: 12,
                          color: _getStatusColor(pr.status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '#${pr.number}',
                          style: AppTheme.premiumBodyStyle.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(pr.status),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Repository badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      repoName,
                      style: AppTheme.premiumBodyStyle.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Author avatar
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: pr.authorAvatar.isNotEmpty
                        ? NetworkImage(pr.authorAvatar)
                        : null,
                    child: pr.authorAvatar.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 12,
                            color: AppTheme.textSecondaryColor,
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                pr.title,
                style: AppTheme.premiumHeadingStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Author and time
              Row(
                children: [
                  Text(
                    'by ${pr.author}',
                    style: AppTheme.premiumBodyStyle.copyWith(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: AppTheme.premiumBodyStyle.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getTimeAgo(pr.updatedAt),
                    style: AppTheme.premiumBodyStyle.copyWith(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  _buildStatChip(
                    Icons.add_circle_outline,
                    '+${pr.additions}',
                    Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    Icons.remove_circle_outline,
                    '-${pr.deletions}',
                    Colors.red,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    Icons.description_outlined,
                    '${pr.filesChanged.length} files',
                    AppTheme.textSecondaryColor,
                  ),
                  const Spacer(),
                  Text(
                    pr.commitSha.length > 7
                        ? pr.commitSha.substring(0, 7)
                        : pr.commitSha,
                    style: AppTheme.premiumBodyStyle.copyWith(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: AppTheme.premiumBodyStyle.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(PRStatus status) {
    switch (status) {
      case PRStatus.merged:
        return Colors.purple;
      case PRStatus.closed:
        return Colors.red;
      case PRStatus.approved:
        return Colors.green;
      case PRStatus.buildPassed:
        return Colors.green;
      case PRStatus.buildFailed:
        return Colors.red;
      case PRStatus.building:
        return Colors.orange;
      default:
        return AppTheme.textSecondaryColor;
    }
  }

  IconData _getStatusIcon(PRStatus status) {
    switch (status) {
      case PRStatus.merged:
        return Icons.merge;
      case PRStatus.closed:
        return Icons.close;
      case PRStatus.approved:
        return Icons.check_circle;
      case PRStatus.buildPassed:
        return Icons.check_circle;
      case PRStatus.buildFailed:
        return Icons.error;
      case PRStatus.building:
        return Icons.hourglass_empty;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}
