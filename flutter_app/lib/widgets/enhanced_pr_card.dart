import 'package:flutter/material.dart';
import '../config/premium_theme.dart';
import '../models/pull_request.dart';
import '../models/ai_insight.dart';

class EnhancedPRCard extends StatefulWidget {
  final PullRequest pullRequest;
  final AIInsight? insight;
  final VoidCallback onTap;

  const EnhancedPRCard({
    super.key,
    required this.pullRequest,
    this.insight,
    required this.onTap,
  });

  @override
  State<EnhancedPRCard> createState() => _EnhancedPRCardState();
}

class _EnhancedPRCardState extends State<EnhancedPRCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: AppTheme.premiumCardDecoration.copyWith(
                boxShadow: _isPressed
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ]
                    : AppTheme.premiumCardDecoration.boxShadow,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with enhanced styling
                  Row(
                    children: [
                      _buildPRNumberBadge(),
                      const Spacer(),
                      _buildStatusBadge(widget.pullRequest.status),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // PR Title with better typography
                  Text(
                    widget.pullRequest.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Enhanced Author and Meta Info
                  _buildAuthorRow(),
                  
                  if (widget.insight != null) ...[
                    const SizedBox(height: 16),
                    _buildAIInsightSection(widget.insight!),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Enhanced bottom section with workflow progress
                  _buildBottomSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPRNumberBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.merge_type_outlined,
            size: 14,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            '#${widget.pullRequest.number}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(PRStatus status) {
    final statusInfo = _getStatusInfo(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusInfo.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusInfo.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIcon(statusInfo),
          const SizedBox(width: 6),
          Text(
            statusInfo.text,
            style: TextStyle(
              color: statusInfo.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(_StatusInfo statusInfo) {
    if (statusInfo.isAnimated) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(statusInfo.color),
        ),
      );
    }
    
    return Icon(
      statusInfo.icon,
      size: 14,
      color: statusInfo.color,
    );
  }

  Widget _buildAuthorRow() {
    return Row(
      children: [
        // Enhanced Author Avatar
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.2),
                AppTheme.primaryColor.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.person_outline,
            size: 20,
            color: AppTheme.primaryColor,
          ),
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.pullRequest.author,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.pullRequest.isDraft)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'DRAFT',
                        style: TextStyle(
                          color: AppTheme.warningColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 12,
                    color: AppTheme.textTertiaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.pullRequest.branchName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textTertiaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Time with enhanced styling
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(widget.pullRequest.updatedAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textTertiaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.pullRequest.filesChanged.length} files',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textHintColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAIInsightSection(AIInsight insight) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.getRiskBackgroundColor(insight.riskLevel.name),
            AppTheme.getRiskBackgroundColor(insight.riskLevel.name).withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.getRiskColor(insight.riskLevel.name).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.getRiskColor(insight.riskLevel.name).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  size: 16,
                  color: AppTheme.getRiskColor(insight.riskLevel.name),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'AI Analysis',
                style: TextStyle(
                  color: AppTheme.getRiskColor(insight.riskLevel.name),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.getRiskColor(insight.riskLevel.name),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  insight.riskLevel.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.summary,
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (insight.confidenceScore > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Confidence: ',
                  style: TextStyle(
                    color: AppTheme.textTertiaryColor,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${(insight.confidenceScore * 100).toInt()}%',
                  style: TextStyle(
                    color: AppTheme.getRiskColor(insight.riskLevel.name),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Row(
      children: [
        // Enhanced Changes Summary
        _buildChangesSummary(),
        const Spacer(),
        // Workflow Progress Indicator
        _buildWorkflowProgress(),
      ],
    );
  }

  Widget _buildChangesSummary() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildChangeBadge(
          '+${widget.pullRequest.additions}',
          AppTheme.successColor,
          Icons.add,
        ),
        const SizedBox(width: 8),
        _buildChangeBadge(
          '-${widget.pullRequest.deletions}',
          AppTheme.errorColor,
          Icons.remove,
        ),
      ],
    );
  }

  Widget _buildChangeBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowProgress() {
    final progress = _calculateProgress(widget.pullRequest.status);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Progress',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textTertiaryColor,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: 80,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.dividerColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _calculateProgress(PRStatus status) {
    switch (status) {
      case PRStatus.pending:
        return 0.2;
      case PRStatus.building:
        return 0.4;
      case PRStatus.buildPassed:
        return 0.6;
      case PRStatus.buildFailed:
        return 0.4;
      case PRStatus.approved:
        return 0.8;
      case PRStatus.merged:
        return 1.0;
      case PRStatus.closed:
        return 0.3;
    }
  }

  _StatusInfo _getStatusInfo(PRStatus status) {
    switch (status) {
      case PRStatus.pending:
        return _StatusInfo(
          text: 'Pending',
          color: AppTheme.warningColor,
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.1),
          icon: Icons.schedule_outlined,
        );
      case PRStatus.building:
        return _StatusInfo(
          text: 'Building',
          color: AppTheme.primaryColor,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          icon: Icons.build_outlined,
          isAnimated: true,
        );
      case PRStatus.buildPassed:
        return _StatusInfo(
          text: 'Build Passed',
          color: AppTheme.successColor,
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.1),
          icon: Icons.check_circle_outline,
        );
      case PRStatus.buildFailed:
        return _StatusInfo(
          text: 'Build Failed',
          color: AppTheme.errorColor,
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
          icon: Icons.error_outline,
        );
      case PRStatus.approved:
        return _StatusInfo(
          text: 'Approved',
          color: AppTheme.successColor,
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.1),
          icon: Icons.thumb_up_outlined,
        );
      case PRStatus.merged:
        return _StatusInfo(
          text: 'Merged',
          color: AppTheme.accentColor,
          backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
          icon: Icons.merge_outlined,
        );
      case PRStatus.closed:
        return _StatusInfo(
          text: 'Closed',
          color: AppTheme.textTertiaryColor,
          backgroundColor: AppTheme.textTertiaryColor.withValues(alpha: 0.1),
          icon: Icons.close_outlined,
        );
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _StatusInfo {
  final String text;
  final Color color;
  final Color backgroundColor;
  final IconData icon;
  final bool isAnimated;

  _StatusInfo({
    required this.text,
    required this.color,
    required this.backgroundColor,
    required this.icon,
    this.isAnimated = false,
  });
}
