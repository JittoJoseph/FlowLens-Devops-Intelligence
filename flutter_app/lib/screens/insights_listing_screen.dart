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

class _InsightsListingScreenState extends State<InsightsListingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<InsightGroup> _insightGroups = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  RiskLevel? _riskFilter;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _loadInsights();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadInsights() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final insights = await ApiService.getInsights();

      // Filter out any insights with invalid data
      final validInsights = insights
          .where(
            (insight) =>
                insight.id.isNotEmpty &&
                insight.prNumber > 0 &&
                insight.summary.isNotEmpty,
          )
          .toList();

      // Group insights by PR
      final Map<String, List<AIInsight>> groupedInsights = {};
      for (final insight in validInsights) {
        final key = 'PR#${insight.prNumber}';
        groupedInsights.putIfAbsent(key, () => []).add(insight);
      }

      // Create insight groups with metadata
      _insightGroups = groupedInsights.entries.map((entry) {
        final insights = entry.value;
        final firstInsight = insights.first;

        return InsightGroup(
          prNumber: firstInsight.prNumber,
          prTitle: 'Pull Request #${firstInsight.prNumber}', // Fallback title
          insights: insights,
          createdAt: insights
              .map((i) => i.createdAt)
              .reduce((a, b) => a.isAfter(b) ? a : b),
          highestRiskLevel: insights
              .map((i) => i.riskLevel)
              .reduce((a, b) => a.index > b.index ? a : b),
        );
      }).toList();

      // Sort by creation date (newest first)
      _insightGroups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _fadeController.forward();
        _slideController.forward();
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

  List<InsightGroup> get _filteredGroups {
    var filtered = _insightGroups;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((group) {
        final query = _searchQuery.toLowerCase();
        return group.prTitle.toLowerCase().contains(query) ||
            group.prNumber.toString().contains(query);
      }).toList();
    }

    if (_riskFilter != null) {
      filtered = filtered.where((group) {
        return group.highestRiskLevel == _riskFilter;
      }).toList();
    }

    return filtered;
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
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildHeader(),
                ),
              ),
            ),

            // Search and Filter Section
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildSearchAndFilters(),
                ),
              ),
            ),

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
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
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
        onTap: () {
          setState(() {
            _riskFilter = isSelected ? null : risk;
          });
        },
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
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final group = _filteredGroups[index];
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: index == _filteredGroups.length - 1 ? 100 : 16,
                ),
                child: _buildInsightGroupCard(group),
              ),
            ),
          );
        }, childCount: _filteredGroups.length),
      ),
    );
  }

  Widget _buildInsightGroupCard(InsightGroup group) {
    final riskColor = _getRiskColor(group.highestRiskLevel);

    return GestureDetector(
      onTap: () {
        // Create a mock PullRequest for navigation
        final mockPR = PullRequest(
          id: 'mock-${group.prNumber}',
          number: group.prNumber,
          title: group.prTitle,
          description: 'AI-generated insights available for this pull request',
          author: 'AI System',
          authorAvatar: '',
          commitSha: 'abcd1234567890',
          repositoryName: 'repository',
          createdAt: DateTime.now().subtract(
            const Duration(hours: 2),
          ), // 2 hours ago
          updatedAt: DateTime.now().subtract(
            const Duration(minutes: 30),
          ), // 30 minutes ago
          status: PRStatus.pending,
          filesChanged: [],
          additions: 0,
          deletions: 0,
          branchName: 'feature-branch',
          isDraft: false,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PremiumInsightsScreen(pullRequest: mockPR),
          ),
        );
      },
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

  InsightGroup({
    required this.prNumber,
    required this.prTitle,
    required this.insights,
    required this.createdAt,
    required this.highestRiskLevel,
  });
}
