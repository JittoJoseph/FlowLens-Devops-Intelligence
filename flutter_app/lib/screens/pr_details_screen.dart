import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pr_provider.dart';
import '../models/pull_request.dart';
import '../models/ai_insight.dart';
import '../config/premium_theme.dart';

class PRDetailsScreen extends StatelessWidget {
  const PRDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PRProvider>(
      builder: (context, prProvider, child) {
        final pr = prProvider.selectedPR;
        if (pr == null) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            appBar: AppBar(
              backgroundColor: AppTheme.backgroundColor,
              elevation: 0,
              title: Text(
                'PR Details',
                style: AppTheme.premiumHeadingStyle.copyWith(fontSize: 18),
              ),
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
              ),
            ),
            body: Center(
              child: Text('No PR selected', style: AppTheme.premiumBodyStyle),
            ),
          );
        }

        final insight = prProvider.getInsightForPR(pr.number);

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: CustomScrollView(
            slivers: [
              // Premium App Bar
              SliverAppBar(
                expandedHeight: 200,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: AppTheme.backgroundColor,
                leading: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'PR #${pr.number}',
                    style: AppTheme.premiumHeadingStyle.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const SizedBox(height: 50), // Account for app bar
                            Text(
                              pr.title,
                              style: AppTheme.premiumHeadingStyle.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'approve':
                          prProvider.updatePRStatus(
                            pr.number,
                            PRStatus.approved,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PR Approved!')),
                          );
                          break;
                        case 'merge':
                          prProvider.updatePRStatus(pr.number, PRStatus.merged);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PR Merged!')),
                          );
                          Navigator.pop(context);
                          break;
                        case 'close':
                          prProvider.updatePRStatus(pr.number, PRStatus.closed);
                          Navigator.pop(context);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (pr.status == PRStatus.buildPassed)
                        const PopupMenuItem(
                          value: 'approve',
                          child: ListTile(
                            leading: Icon(Icons.thumb_up),
                            title: Text('Approve'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      if (pr.status == PRStatus.approved)
                        const PopupMenuItem(
                          value: 'merge',
                          child: ListTile(
                            leading: Icon(Icons.merge_type),
                            title: Text('Merge'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'close',
                        child: ListTile(
                          leading: Icon(Icons.close),
                          title: Text('Close'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status and Info Row
                      Row(
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                pr.status,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getStatusColor(
                                  pr.status,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(pr.status),
                                  size: 18,
                                  color: _getStatusColor(pr.status),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getStatusText(pr.status),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: _getStatusColor(pr.status),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // Time
                          Text(
                            'Updated ${_formatTimeAgo(pr.updatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                                ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Author Section
                      _buildAuthorSection(context, pr),

                      const SizedBox(height: 24),

                      // AI Insight Section
                      if (insight != null) ...[
                        _buildAIInsightSection(context, insight),
                        const SizedBox(height: 24),
                      ],

                      // Workflow Progress
                      _buildWorkflowSection(context, pr),

                      const SizedBox(height: 24),

                      // Description
                      _buildDescriptionSection(context, pr),

                      const SizedBox(height: 24),

                      // Changes Section
                      _buildChangesSection(context, pr),

                      const SizedBox(height: 100), // Bottom padding
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuthorSection(BuildContext context, PullRequest pr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                pr.author.substring(0, 1).toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pr.author,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'wants to merge from ${pr.branchName}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Created ${_formatTimeAgo(pr.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pr.commitSha.substring(0, 7),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIInsightSection(BuildContext context, AIInsight insight) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'AI Analysis',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getRiskBackgroundColor(
                      insight.riskLevel.name,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getRiskIcon(insight.riskLevel),
                        size: 16,
                        color: AppTheme.getRiskColor(insight.riskLevel.name),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        insight.riskLevel.displayName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getRiskColor(insight.riskLevel.name),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                insight.summary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.getRiskBackgroundColor(insight.riskLevel.name),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.getRiskColor(
                    insight.riskLevel.name,
                  ).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: AppTheme.getRiskColor(insight.riskLevel.name),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recommendation',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getRiskColor(insight.riskLevel.name),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    insight.recommendation,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.getRiskColor(insight.riskLevel.name),
                    ),
                  ),
                ],
              ),
            ),

            if (insight.keyChanges.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Key Changes Detected:',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...insight.keyChanges.map(
                (change) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record, size: 8),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          change,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowSection(BuildContext context, PullRequest pr) {
    final stages = [
      {'name': 'PR Created', 'icon': Icons.note_add, 'completed': true},
      {
        'name': 'Build Started',
        'icon': Icons.build,
        'completed': pr.status != PRStatus.pending,
      },
      {
        'name': 'Tests Pass',
        'icon': Icons.check_circle,
        'completed':
            pr.status == PRStatus.buildPassed ||
            pr.status == PRStatus.approved ||
            pr.status == PRStatus.merged,
      },
      {
        'name': 'Code Review',
        'icon': Icons.rate_review,
        'completed':
            pr.status == PRStatus.approved || pr.status == PRStatus.merged,
      },
      {
        'name': 'Merged',
        'icon': Icons.merge_type,
        'completed': pr.status == PRStatus.merged,
      },
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workflow Progress',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...stages.asMap().entries.map((entry) {
              final index = entry.key;
              final stage = entry.value;
              final isLast = index == stages.length - 1;

              return Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: stage['completed'] as bool
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          stage['icon'] as IconData,
                          color: stage['completed'] as bool
                              ? Colors.white
                              : Theme.of(context).colorScheme.outline,
                          size: 20,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 30,
                          color: stage['completed'] as bool
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.3)
                              : Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.2),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 30),
                      child: Text(
                        stage['name'] as String,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: stage['completed'] as bool
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: stage['completed'] as bool
                              ? Theme.of(context).textTheme.bodyMedium?.color
                              : Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context, PullRequest pr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              pr.description.isNotEmpty
                  ? pr.description
                  : 'No description provided.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangesSection(BuildContext context, PullRequest pr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Changes',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${pr.additions}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '-${pr.deletions}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Files Changed (${pr.filesChanged.length})',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...pr.filesChanged.map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      _getFileIcon(file),
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRiskIcon(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.low:
        return Icons.check_circle;
      case RiskLevel.medium:
        return Icons.warning;
      case RiskLevel.high:
        return Icons.error;
    }
  }

  IconData _getFileIcon(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'dart':
        return Icons.code;
      case 'py':
        return Icons.code;
      case 'js':
      case 'ts':
        return Icons.javascript;
      case 'md':
        return Icons.description;
      case 'yaml':
      case 'yml':
        return Icons.settings;
      case 'json':
        return Icons.data_object;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getStatusColor(PRStatus status) {
    switch (status) {
      case PRStatus.pending:
        return const Color(0xFF6B7280);
      case PRStatus.building:
        return const Color(0xFFF59E0B);
      case PRStatus.buildPassed:
        return const Color(0xFF10B981);
      case PRStatus.buildFailed:
        return const Color(0xFFEF4444);
      case PRStatus.approved:
        return const Color(0xFF8B5CF6);
      case PRStatus.merged:
        return const Color(0xFF059669);
      case PRStatus.closed:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getStatusIcon(PRStatus status) {
    switch (status) {
      case PRStatus.pending:
        return Icons.schedule;
      case PRStatus.building:
        return Icons.build_circle;
      case PRStatus.buildPassed:
        return Icons.check_circle;
      case PRStatus.buildFailed:
        return Icons.error;
      case PRStatus.approved:
        return Icons.thumb_up;
      case PRStatus.merged:
        return Icons.merge_type;
      case PRStatus.closed:
        return Icons.close;
    }
  }

  String _getStatusText(PRStatus status) {
    switch (status) {
      case PRStatus.pending:
        return 'Pending Review';
      case PRStatus.building:
        return 'Building';
      case PRStatus.buildPassed:
        return 'Build Passed';
      case PRStatus.buildFailed:
        return 'Build Failed';
      case PRStatus.approved:
        return 'Approved';
      case PRStatus.merged:
        return 'Merged';
      case PRStatus.closed:
        return 'Closed';
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
