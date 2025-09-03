import 'package:flutter/material.dart';
import '../config/premium_theme.dart';
import '../services/api_service.dart';
import '../models/ai_insight.dart';
import '../models/pull_request.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/modern_floating_action_button.dart';
import '../screens/premium_insights_screen.dart';

class InsightsListingScreen extends StatefulWidget {
  const InsightsListingScreen({super.key});

  @override
  State<InsightsListingScreen> createState() => _InsightsListingScreenState();
}

class _InsightsListingScreenState extends State<InsightsListingScreen> {
  List<InsightGroup> _insightGroups = [];
  List<InsightGroup> _filteredGroups = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  RiskLevel? _riskFilter;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final insights = await ApiService.getInsights();
      _processInsights(insights);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load insights. Please try again.';
        });
      }
    }
  }

  // Simplified data processing method
  void _processInsights(List<AIInsight> insights) {
    final Map<int, List<AIInsight>> groupedInsights = {};

    // Group insights by PR number
    for (final insight in insights) {
      if (insight.id.isNotEmpty &&
          insight.prNumber > 0 &&
          insight.summary.isNotEmpty) {
        groupedInsights.putIfAbsent(insight.prNumber, () => []).add(insight);
      }
    }

    // Create insight groups
    final groups = <InsightGroup>[];
    for (final entry in groupedInsights.entries) {
      final prInsights = entry.value;
      final firstInsight = prInsights.first;

      // Find highest risk and latest date efficiently
      var highestRisk = RiskLevel.low;
      var latestDate = prInsights.first.createdAt;

      for (final insight in prInsights) {
        if (insight.riskLevel.index > highestRisk.index) {
          highestRisk = insight.riskLevel;
        }
        if (insight.createdAt.isAfter(latestDate)) {
          latestDate = insight.createdAt;
        }
      }

      groups.add(
        InsightGroup(
          prNumber: firstInsight.prNumber,
          prTitle: 'Pull Request #${firstInsight.prNumber}',
          insights: prInsights,
          createdAt: latestDate,
          highestRiskLevel: highestRisk,
        ),
      );
    }

    // Sort by creation date (newest first)
    groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _insightGroups = groups;
    _applyFilters();
  }

  // Simple filtering method
  void _applyFilters() {
    var filtered = _insightGroups;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((group) {
        return group.prTitle.toLowerCase().contains(query) ||
            group.prNumber.toString().contains(query);
      }).toList();
    }

    if (_riskFilter != null) {
      filtered = filtered.where((group) {
        return group.highestRiskLevel == _riskFilter;
      }).toList();
    }

    _filteredGroups = filtered;
  }

  void _updateSearch(String value) {
    setState(() {
      _searchQuery = value;
      _applyFilters();
    });
  }

  void _updateRiskFilter(RiskLevel? risk) {
    setState(() {
      _riskFilter = _riskFilter == risk ? null : risk;
      _applyFilters();
    });
  }

  void _navigateToInsights(InsightGroup group) {
    // Create a PullRequest object from the insight data for navigation
    final firstInsight = group.insights.first;

    final pullRequest = PullRequest(
      id: 'insight-${group.prNumber}',
      number: group.prNumber,
      title: group.prTitle,
      description:
          'Pull request with ${group.insights.length} AI insight${group.insights.length > 1 ? 's' : ''}',
      author: firstInsight.author,
      authorAvatar: firstInsight.avatarUrl,
      commitSha: firstInsight.commitSha,
      repositoryName:
          'repository', // TODO: Get actual repository name if available
      createdAt: group.createdAt,
      updatedAt: group.createdAt,
      status: PRStatus
          .pending, // Default status since we don't have this in insights
      filesChanged: [],
      additions: 0,
      deletions: 0,
      branchName: 'feature-branch',
      isDraft: false,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PremiumInsightsScreen(pullRequest: pullRequest),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        elevation: 0,
        title: Text(
          'AI Insights',
          style: AppTheme.premiumHeadingStyle.copyWith(fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimaryColor),
      ),
      drawer: const AppSidebar(),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header Section
            SliverToBoxAdapter(child: _buildHeader()),

            // Search and Filter Section
            SliverToBoxAdapter(child: _buildSearchAndFilters()),

            // Content
            if (_isLoading)
              SliverToBoxAdapter(child: _buildLoadingState())
            else if (_errorMessage != null)
              SliverToBoxAdapter(child: _buildErrorState())
            else if (_filteredGroups.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
            else
              _buildInsightsList(),
          ],
        ),
      ),
      floatingActionButton: const ModernFloatingActionButton(),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.premiumCardDecoration.copyWith(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Insights Dashboard',
                      style: AppTheme.premiumHeadingStyle.copyWith(
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Discover intelligent analysis across all pull requests',
                      style: AppTheme.premiumBodyStyle.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildHeroContent(),
        ],
      ),
    );
  }

  Widget _buildHeroContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.accentColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI-Powered Code Intelligence',
                      style: AppTheme.premiumHeadingStyle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Discover insights to improve code quality and reduce risks',
                      style: AppTheme.premiumBodyStyle.copyWith(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureTag('AI Analysis', Icons.psychology),
              _buildFeatureTag('Risk Detection', Icons.security),
              _buildFeatureTag('Performance', Icons.speed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.premiumBodyStyle.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: AppTheme.premiumCardDecoration,
            child: TextField(
              onChanged: _updateSearch,
              style: AppTheme.premiumBodyStyle,
              decoration: InputDecoration(
                hintText: 'Search by PR title or number...',
                hintStyle: AppTheme.premiumBodyStyle.copyWith(
                  color: AppTheme.textTertiaryColor,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppTheme.textSecondaryColor,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Risk Level Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRiskFilter('All', null),
                const SizedBox(width: 12),
                _buildRiskFilter('Low', RiskLevel.low),
                const SizedBox(width: 12),
                _buildRiskFilter('Medium', RiskLevel.medium),
                const SizedBox(width: 12),
                _buildRiskFilter('High', RiskLevel.high),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRiskFilter(String label, RiskLevel? risk) {
    final isSelected = _riskFilter == risk;
    final color = risk != null ? _getRiskColor(risk) : AppTheme.primaryColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: () => _updateRiskFilter(risk),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.1)
                : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? color
                  : AppTheme.dividerColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: AppTheme.premiumBodyStyle.copyWith(
              color: isSelected ? color : AppTheme.textSecondaryColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.builder(
        itemCount: _filteredGroups.length,
        itemBuilder: (context, index) {
          final group = _filteredGroups[index];
          return RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: index == _filteredGroups.length - 1 ? 100 : 16,
              ),
              child: _buildInsightGroupCard(group),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInsightGroupCard(InsightGroup group) {
    final riskColor = _getRiskColor(group.highestRiskLevel);

    return GestureDetector(
      onTap: () => _navigateToInsights(group),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: AppTheme.premiumCardDecoration.copyWith(
          border: Border.all(color: riskColor.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getRiskIcon(group.highestRiskLevel),
                      color: riskColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PR #${group.prNumber}',
                          style: AppTheme.premiumHeadingStyle.copyWith(
                            fontSize: 16,
                            color: riskColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          group.prTitle,
                          style: AppTheme.premiumBodyStyle.copyWith(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.textTertiaryColor,
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Insights summary
                  Row(
                    children: [
                      Icon(
                        Icons.insights,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${group.insights.length} insight${group.insights.length != 1 ? 's' : ''}',
                        style: AppTheme.premiumBodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTimeAgo(group.createdAt),
                        style: AppTheme.premiumBodyStyle.copyWith(
                          fontSize: 12,
                          color: AppTheme.textTertiaryColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Risk level breakdown
                  Wrap(
                    spacing: 8,
                    children: _buildRiskLevelChips(group.insights),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRiskLevelChips(List<AIInsight> insights) {
    final riskCounts = <RiskLevel, int>{};
    for (final insight in insights) {
      riskCounts[insight.riskLevel] = (riskCounts[insight.riskLevel] ?? 0) + 1;
    }

    return riskCounts.entries.map((entry) {
      final risk = entry.key;
      final count = entry.value;
      final color = _getRiskColor(risk);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${risk.displayName}: $count',
          style: AppTheme.premiumBodyStyle.copyWith(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading AI insights...',
              style: AppTheme.premiumBodyStyle.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 30,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to load insights',
              style: AppTheme.premiumHeadingStyle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unexpected error occurred',
              style: AppTheme.premiumBodyStyle.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadInsights,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.psychology_outlined,
                color: AppTheme.primaryColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No insights found',
              style: AppTheme.premiumHeadingStyle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _riskFilter != null
                  ? 'Try adjusting your search or filters'
                  : 'AI insights will appear here as pull requests are analyzed',
              style: AppTheme.premiumBodyStyle.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.low:
        return Colors.green;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.high:
        return Colors.red;
    }
  }

  IconData _getRiskIcon(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.low:
        return Icons.check_circle_outline;
      case RiskLevel.medium:
        return Icons.warning_amber_outlined;
      case RiskLevel.high:
        return Icons.error_outline;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
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

// Data model for grouped insights
class InsightGroup {
  final int prNumber;
  final String prTitle;
  final List<AIInsight> insights;
  final DateTime createdAt;
  final RiskLevel highestRiskLevel;

  const InsightGroup({
    required this.prNumber,
    required this.prTitle,
    required this.insights,
    required this.createdAt,
    required this.highestRiskLevel,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InsightGroup && other.prNumber == prNumber;
  }

  @override
  int get hashCode => prNumber.hashCode;
}
