import 'package:flutter/material.dart';
import '../config/premium_theme.dart';
import '../models/pipeline_run.dart';
import '../models/repository.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/modern_floating_action_button.dart';

class PipelineScreen extends StatefulWidget {
  const PipelineScreen({super.key});

  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen>
    with TickerProviderStateMixin {
  List<PipelineRun> _pipelines = [];
  List<Repository> _repositories = [];
  String? _selectedRepositoryId;
  String _selectedStatusFilter = 'all';
  bool _isLoading = false;
  String? _error;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<String> _statusFilters = [
    'all',
    'building',
    'passed',
    'failed',
    'merged',
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadData();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repositories = await ApiService.getRepositories();
      final pipelines = await ApiService.getPipelines(
        repositoryId: _selectedRepositoryId,
      );

      setState(() {
        _repositories = repositories;
        _pipelines = pipelines;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load pipeline data: $e';
        _isLoading = false;
      });
    }
  }

  List<PipelineRun> get _filteredPipelines {
    return _pipelines.where((pipeline) {
      // Status filter
      if (_selectedStatusFilter != 'all') {
        final status = pipeline.overallStatus;
        if (_selectedStatusFilter == 'building' && status != 'building') {
          return false;
        }
        if (_selectedStatusFilter == 'passed' && status != 'passed') {
          return false;
        }
        if (_selectedStatusFilter == 'failed' && status != 'failed') {
          return false;
        }
        if (_selectedStatusFilter == 'merged' && status != 'merged') {
          return false;
        }
      }
      return true;
    }).toList();
  }

  String _getRepositoryName(String repoId) {
    final repo = _repositories.firstWhere(
      (r) => r.id == repoId,
      orElse: () => Repository(
        id: '',
        name: 'Unknown Repo',
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
          'CI/CD Pipeline',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildStatsHeader(),
                  _buildFiltersSection(),
                  _buildContent(),
                ],
              ),
            ),
      floatingActionButton: const ModernFloatingActionButton(),
    );
  }

  Widget _buildStatsHeader() {
    if (_pipelines.isEmpty) {
      return Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.1),
              AppTheme.primaryColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            'No pipeline data available',
            style: AppTheme.premiumBodyStyle.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
      );
    }

    final filteredPipelines = _filteredPipelines;
    final buildingCount = filteredPipelines
        .where((p) => p.overallStatus == 'building')
        .length;
    final passedCount = filteredPipelines
        .where((p) => p.overallStatus == 'passed')
        .length;
    final failedCount = filteredPipelines
        .where((p) => p.overallStatus == 'failed')
        .length;
    final mergedCount = filteredPipelines
        .where((p) => p.overallStatus == 'merged')
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.primaryColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                'Pipeline Overview',
                style: AppTheme.premiumHeadingStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatCard(
                  'Building',
                  buildingCount.toString(),
                  Icons.autorenew,
                  Colors.orange,
                  isAnimated: buildingCount > 0,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Passed',
                  passedCount.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Failed',
                  failedCount.toString(),
                  Icons.error,
                  Colors.red,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Merged',
                  mergedCount.toString(),
                  Icons.merge,
                  Colors.purple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isAnimated = false,
  }) {
    Widget child = Container(
      width: 80, // Fixed width to prevent overflow
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.premiumHeadingStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: AppTheme.premiumBodyStyle.copyWith(
              fontSize: 10,
              color: AppTheme.textSecondaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (isAnimated) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _pulseAnimation.value, child: child);
        },
        child: child,
      );
    }

    return child;
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use column layout for narrow screens
          if (constraints.maxWidth < 600) {
            return Column(
              children: [
                // Repository filter
                DropdownButtonFormField<String?>(
                  initialValue: _selectedRepositoryId,
                  decoration: InputDecoration(
                    labelText: 'Repository',
                    prefixIcon: Icon(
                      Icons.account_tree_outlined,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
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
                    _loadData();
                  },
                ),
                const SizedBox(height: 12),

                // Status filter
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatusFilter,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(
                      Icons.filter_list,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
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
                            status == 'all' ? 'All' : _capitalizeFirst(status),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatusFilter = value ?? 'all';
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
                    prefixIcon: Icon(
                      Icons.account_tree_outlined,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
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
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Status filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatusFilter,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(
                      Icons.filter_list,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
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
                            status == 'all' ? 'All' : _capitalizeFirst(status),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatusFilter = value ?? 'all';
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent() {
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

    final filteredPipelines = _filteredPipelines;

    if (filteredPipelines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.build_outlined,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No pipeline runs found',
              style: AppTheme.premiumHeadingStyle.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
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
        children: filteredPipelines
            .map((pipeline) => _buildPipelineCard(pipeline))
            .toList(),
      ),
    );
  }

  Widget _buildPipelineCard(PipelineRun pipeline) {
    final repoName = _getRepositoryName(pipeline.repoId);
    final status = pipeline.overallStatus;
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: status == 'building'
                      ? AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _pulseController.value * 2 * 3.14159,
                              child: Icon(
                                Icons.settings,
                                color: statusColor,
                                size: 20,
                              ),
                            );
                          },
                        )
                      : Icon(
                          _getStatusIcon(status),
                          color: statusColor,
                          size: 20,
                        ),
                ),
                const SizedBox(width: 12),

                // Title and repo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pipeline.title,
                        style: AppTheme.premiumHeadingStyle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.account_tree_outlined,
                            size: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            repoName,
                            style: AppTheme.premiumBodyStyle.copyWith(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PR #${pipeline.prNumber}',
                            style: AppTheme.premiumBodyStyle.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _capitalizeFirst(status),
                    style: AppTheme.premiumBodyStyle.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author and commit info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: pipeline.avatarUrl.isNotEmpty
                          ? NetworkImage(pipeline.avatarUrl)
                          : null,
                      child: pipeline.avatarUrl.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 12,
                              color: AppTheme.textSecondaryColor,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pipeline.author,
                      style: AppTheme.premiumBodyStyle.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.dividerColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pipeline.shortCommitSha,
                        style: AppTheme.premiumBodyStyle.copyWith(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Pipeline timeline
                if (pipeline.cleanedHistory.isNotEmpty)
                  _buildPipelineTimeline(pipeline),

                // Duration and timestamps
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Duration: ${_formatDuration(pipeline.totalDuration)}',
                      style: AppTheme.premiumBodyStyle.copyWith(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _getTimeAgo(pipeline.updatedAt),
                      style: AppTheme.premiumBodyStyle.copyWith(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineTimeline(PipelineRun pipeline) {
    final events = pipeline.cleanedHistory
        .take(5)
        .toList(); // Show max 5 events

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.dividerColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pipeline Steps',
            style: AppTheme.premiumBodyStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          ...events.asMap().entries.map((entry) {
            final index = entry.key;
            final event = entry.value;
            final isLast = index == events.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getEventStatusColor(event.value),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 20,
                        color: AppTheme.dividerColor.withValues(alpha: 0.3),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.eventDescription,
                          style: AppTheme.premiumBodyStyle.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _getTimeAgo(event.timestamp),
                          style: AppTheme.premiumBodyStyle.copyWith(
                            fontSize: 10,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'building':
        return Colors.orange;
      case 'passed':
      case 'ready':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'merged':
        return Colors.purple;
      default:
        return AppTheme.textSecondaryColor;
    }
  }

  Color _getEventStatusColor(String value) {
    switch (value) {
      case 'buildPassed':
      case 'approved':
        return Colors.green;
      case 'buildFailed':
      case 'rejected':
        return Colors.red;
      case 'building':
      case 'pending':
        return Colors.orange;
      case 'merged':
        return Colors.purple;
      case 'opened':
        return Colors.blue;
      case 'closed':
        return Colors.grey;
      default:
        return AppTheme.textSecondaryColor;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'building':
        return Icons.settings;
      case 'passed':
      case 'ready':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'merged':
        return Icons.merge;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
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
