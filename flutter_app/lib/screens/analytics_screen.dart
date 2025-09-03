import 'package:flutter/material.dart';
import '../config/premium_theme.dart';
import '../models/pull_request.dart';
import '../models/pipeline_run.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/modern_floating_action_button.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  List<PullRequest> _pullRequests = [];
  List<PipelineRun> _pipelines = [];
  bool _isLoading = false;
  String? _error;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadData();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pullRequests = await ApiService.getPullRequests();
      final pipelines = await ApiService.getPipelines();

      setState(() {
        _pullRequests = pullRequests;
        _pipelines = pipelines;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load analytics data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: const AppSidebar(),
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        elevation: 0,
        foregroundColor: AppTheme.textPrimaryColor,
        iconTheme: IconThemeData(color: AppTheme.textPrimaryColor),
        title: Text(
          'Analytics',
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
      body: _buildContent(),
      floatingActionButton: const ModernFloatingActionButton(),
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

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            _buildOverviewSection(),
            const SizedBox(height: 24),

            // Merge Time Analysis
            _buildMergeTimeSection(),
            const SizedBox(height: 24),

            // Pipeline Success Rate
            _buildPipelineAnalysisSection(),
            const SizedBox(height: 24),

            // Activity Trends
            _buildActivityTrendsSection(),
            const SizedBox(height: 24),

            // Performance Metrics
            _buildPerformanceMetricsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    final totalPRs = _pullRequests.length;
    final mergedPRs = _pullRequests
        .where((pr) => pr.status == PRStatus.merged)
        .length;
    final totalPipelines = _pipelines.length;
    final successfulPipelines = _pipelines
        .where(
          (p) => p.overallStatus == 'passed' || p.overallStatus == 'merged',
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: AppTheme.premiumHeadingStyle.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Use column layout for narrow screens, row for wide screens
            if (constraints.maxWidth < 600) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildOverviewCard(
                          'Total PRs',
                          totalPRs.toString(),
                          Icons.merge_outlined,
                          AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOverviewCard(
                          'Merged',
                          mergedPRs.toString(),
                          Icons.check_circle_outline,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOverviewCard(
                          'Pipelines',
                          totalPipelines.toString(),
                          Icons.build_outlined,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOverviewCard(
                          'Success Rate',
                          totalPipelines > 0
                              ? '${(successfulPipelines / totalPipelines * 100).toInt()}%'
                              : '0%',
                          Icons.trending_up,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            // Wide screen layout - all in one row
            return Row(
              children: [
                Expanded(
                  child: _buildOverviewCard(
                    'Total PRs',
                    totalPRs.toString(),
                    Icons.merge_outlined,
                    AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOverviewCard(
                    'Merged',
                    mergedPRs.toString(),
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOverviewCard(
                    'Pipelines',
                    totalPipelines.toString(),
                    Icons.build_outlined,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOverviewCard(
                    'Success Rate',
                    totalPipelines > 0
                        ? '${(successfulPipelines / totalPipelines * 100).toInt()}%'
                        : '0%',
                    Icons.trending_up,
                    Colors.purple,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return IntrinsicHeight(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTheme.premiumHeadingStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: AppTheme.premiumBodyStyle.copyWith(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMergeTimeSection() {
    final mergedPRs = _pullRequests
        .where((pr) => pr.status == PRStatus.merged)
        .toList();

    if (mergedPRs.isEmpty) {
      return _buildEmptySection(
        'Merge Time Analysis',
        'No merged PRs available for analysis',
      );
    }

    // Calculate average merge time
    final mergeTimes = mergedPRs.map((pr) {
      return pr.updatedAt.difference(pr.createdAt);
    }).toList();

    final avgMergeTime =
        mergeTimes.fold(Duration.zero, (sum, duration) => sum + duration) ~/
        mergeTimes.length;
    final fastestMerge = mergeTimes.reduce((a, b) => a < b ? a : b);
    final slowestMerge = mergeTimes.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Merge Time Analysis',
          style: AppTheme.premiumHeadingStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Average',
                      _formatDuration(avgMergeTime),
                      Icons.schedule,
                      AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricItem(
                      'Fastest',
                      _formatDuration(fastestMerge),
                      Icons.flash_on,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricItem(
                      'Slowest',
                      _formatDuration(slowestMerge),
                      Icons.hourglass_bottom,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildMergeTimeChart(mergeTimes),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineAnalysisSection() {
    if (_pipelines.isEmpty) {
      return _buildEmptySection(
        'Pipeline Analysis',
        'No pipeline data available',
      );
    }

    final buildingCount = _pipelines
        .where((p) => p.overallStatus == 'building')
        .length;
    final passedCount = _pipelines
        .where((p) => p.overallStatus == 'passed')
        .length;
    final failedCount = _pipelines
        .where((p) => p.overallStatus == 'failed')
        .length;
    final mergedCount = _pipelines
        .where((p) => p.overallStatus == 'merged')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pipeline Success Analysis',
          style: AppTheme.premiumHeadingStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatusBar(
                      'Building',
                      buildingCount,
                      Colors.orange,
                      _pipelines.length,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatusBar(
                      'Passed',
                      passedCount,
                      Colors.green,
                      _pipelines.length,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatusBar(
                      'Failed',
                      failedCount,
                      Colors.red,
                      _pipelines.length,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatusBar(
                      'Merged',
                      mergedCount,
                      Colors.purple,
                      _pipelines.length,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTrendsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity Trends',
          style: AppTheme.premiumHeadingStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildTrendItem(
                'PRs This Week',
                _getPRsThisWeek().toString(),
                Icons.trending_up,
                Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildTrendItem(
                'Pipelines This Week',
                _getPipelinesThisWeek().toString(),
                Icons.build,
                Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildTrendItem(
                'Average Daily Activity',
                _getAverageDailyActivity(),
                Icons.timeline,
                AppTheme.primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Metrics',
          style: AppTheme.premiumHeadingStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildPerformanceItem(
                'Code Review Time',
                _getAverageReviewTime(),
                Icons.rate_review,
              ),
              const SizedBox(height: 16),
              _buildPerformanceItem(
                'Build Success Rate',
                _getBuildSuccessRate(),
                Icons.check_circle,
              ),
              const SizedBox(height: 16),
              _buildPerformanceItem(
                'Deployment Frequency',
                _getDeploymentFrequency(),
                Icons.rocket_launch,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySection(String title, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.premiumHeadingStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.dividerColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 48,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: AppTheme.premiumBodyStyle.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
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
            fontSize: 11,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMergeTimeChart(List<Duration> mergeTimes) {
    // Simple visualization - could be enhanced with actual charting library
    final buckets = <String, int>{
      '< 1 day': 0,
      '1-3 days': 0,
      '3-7 days': 0,
      '> 1 week': 0,
    };

    for (final duration in mergeTimes) {
      if (duration.inDays < 1) {
        buckets['< 1 day'] = buckets['< 1 day']! + 1;
      } else if (duration.inDays <= 3) {
        buckets['1-3 days'] = buckets['1-3 days']! + 1;
      } else if (duration.inDays <= 7) {
        buckets['3-7 days'] = buckets['3-7 days']! + 1;
      } else {
        buckets['> 1 week'] = buckets['> 1 week']! + 1;
      }
    }

    final maxCount = buckets.values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Merge Time Distribution',
          style: AppTheme.premiumBodyStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...buckets.entries.map((entry) {
          final percentage = maxCount > 0 ? entry.value / maxCount : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    entry.key,
                    style: AppTheme.premiumBodyStyle.copyWith(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percentage,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value}',
                  style: AppTheme.premiumBodyStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatusBar(String label, int count, Color color, int total) {
    final percentage = total > 0 ? count / total : 0.0;

    return Column(
      children: [
        Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.bottomCenter,
            heightFactor: percentage,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: AppTheme.premiumHeadingStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTheme.premiumBodyStyle.copyWith(
            fontSize: 11,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.premiumBodyStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: AppTheme.premiumBodyStyle.copyWith(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTheme.premiumBodyStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: AppTheme.premiumBodyStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  int _getPRsThisWeek() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _pullRequests.where((pr) => pr.createdAt.isAfter(weekAgo)).length;
  }

  int _getPipelinesThisWeek() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _pipelines.where((p) => p.createdAt.isAfter(weekAgo)).length;
  }

  String _getAverageDailyActivity() {
    if (_pullRequests.isEmpty) return '0 PRs/day';

    final oldestPR = _pullRequests
        .map((pr) => pr.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final daysSinceOldest = DateTime.now().difference(oldestPR).inDays;

    if (daysSinceOldest == 0) return '${_pullRequests.length} PRs/day';

    final avgDaily = _pullRequests.length / daysSinceOldest;
    return '${avgDaily.toStringAsFixed(1)} PRs/day';
  }

  String _getAverageReviewTime() {
    final mergedPRs = _pullRequests
        .where((pr) => pr.status == PRStatus.merged)
        .toList();
    if (mergedPRs.isEmpty) return 'N/A';

    final avgTime =
        mergedPRs
            .map((pr) => pr.updatedAt.difference(pr.createdAt))
            .fold(Duration.zero, (sum, duration) => sum + duration) ~/
        mergedPRs.length;

    return _formatDuration(avgTime);
  }

  String _getBuildSuccessRate() {
    if (_pipelines.isEmpty) return 'N/A';

    final successfulBuilds = _pipelines
        .where(
          (p) => p.overallStatus == 'passed' || p.overallStatus == 'merged',
        )
        .length;

    final rate = (successfulBuilds / _pipelines.length * 100).toInt();
    return '$rate%';
  }

  String _getDeploymentFrequency() {
    final mergedPipelines = _pipelines
        .where((p) => p.overallStatus == 'merged')
        .toList();
    if (mergedPipelines.isEmpty) return 'N/A';

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final recentDeployments = mergedPipelines
        .where((p) => p.updatedAt.isAfter(weekAgo))
        .length;

    return '$recentDeployments/week';
  }
}
