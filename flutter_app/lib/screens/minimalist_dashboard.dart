import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/premium_theme.dart';
import '../providers/github_provider.dart';
import '../providers/pr_provider.dart';
import '../widgets/enhanced_pr_card.dart';
import '../widgets/modern_floating_action_button.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/status_filter_chips.dart';
import '../models/pull_request.dart';
import '../screens/premium_insights_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String _searchQuery = '';
  PRStatus? _statusFilter;
  StreamSubscription? _newPRSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();

    // Load data after the frame is built to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _setupNewPRListener();
    });
  }

  void _setupNewPRListener() {
    final prProvider = Provider.of<PRProvider>(context, listen: false);
    _newPRSubscription = prProvider.newPRStream.listen((newPR) {
      // Show a subtle notification when a new PR is automatically added
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.new_releases, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New PR #${newPR.number}: ${newPR.title}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    });
  }

  void _loadData() async {
    final prProvider = Provider.of<PRProvider>(context, listen: false);
    final githubProvider = Provider.of<GitHubProvider>(context, listen: false);

    // Ensure repositories are loaded if user is connected
    if (githubProvider.isConnected && githubProvider.repositories.isEmpty) {
      await githubProvider.loadRepositories();
    }

    // If no specific repository is selected, load PRs from all repositories
    // Otherwise, load PRs for the selected repository
    final repositoryId = githubProvider.selectedRepository?.id;
    await prProvider.loadPullRequests(repositoryId: repositoryId);
  }

  @override
  void dispose() {
    _newPRSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
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
        title: Consumer<GitHubProvider>(
          builder: (context, githubProvider, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FlowLens',
                  style: AppTheme.premiumHeadingStyle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (githubProvider.isConnected &&
                    githubProvider.selectedRepository != null)
                  Text(
                    githubProvider.selectedRepository!.name,
                    style: AppTheme.premiumBodyStyle.copyWith(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (githubProvider.isConnected)
                  Text(
                    'All Repositories',
                    style: AppTheme.premiumBodyStyle.copyWith(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    'DevOps Dashboard',
                    style: AppTheme.premiumBodyStyle.copyWith(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            );
          },
        ),
        actions: [
          // Background fetching indicator
          Consumer<PRProvider>(
            builder: (context, prProvider, child) {
              if (prProvider.isFetchingNewPR) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'New PR',
                        style: AppTheme.premiumBodyStyle.copyWith(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            onPressed: _loadData,
            icon: Icon(Icons.refresh, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Main Content
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 16),

                        // Repository Header
                        _buildRepositoryHeader(),

                        const SizedBox(height: 24),

                        // Stats Cards
                        _buildStatsRow(),

                        const SizedBox(height: 24),

                        // Search Bar
                        _buildSearchBar(),

                        const SizedBox(height: 16),

                        // Status Filter Chips
                        _buildStatusFilter(),

                        const SizedBox(height: 20),

                        // Section Header
                        _buildSectionHeader(),

                        const SizedBox(height: 16),
                      ]),
                    ),
                  ),

                  // Pull Requests List
                  Consumer<PRProvider>(
                    builder: (context, prProvider, child) {
                      if (prProvider.isLoading) {
                        return const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (prProvider.errorMessage != null) {
                        return SliverFillRemaining(
                          child: _buildErrorState(prProvider.errorMessage!),
                        );
                      }

                      final filteredPRs = _getFilteredPRs(
                        prProvider.pullRequests,
                      );

                      if (filteredPRs.isEmpty) {
                        return SliverFillRemaining(
                          child: _buildEmptyPRsState(),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            if (index == filteredPRs.length) {
                              return const SizedBox(
                                height: 100,
                              ); // Bottom padding
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AnimatedBuilder(
                                animation: _animationController,
                                builder: (context, child) {
                                  return SlideTransition(
                                    position:
                                        Tween<Offset>(
                                          begin: const Offset(0, 0.3),
                                          end: Offset.zero,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: _animationController,
                                            curve: Interval(
                                              (index * 0.1).clamp(0.0, 1.0),
                                              ((index * 0.1) + 0.5).clamp(
                                                0.0,
                                                1.0,
                                              ),
                                              curve: Curves.easeOutCubic,
                                            ),
                                          ),
                                        ),
                                    child: EnhancedPRCard(
                                      pullRequest: filteredPRs[index],
                                      insight: prProvider.getInsightForPR(
                                        filteredPRs[index].number,
                                        repositoryId:
                                            filteredPRs[index].repositoryId,
                                      ),
                                      onTap: () {
                                        // Set the selected PR in the provider
                                        final prProvider =
                                            Provider.of<PRProvider>(
                                              context,
                                              listen: false,
                                            );
                                        prProvider.selectPR(filteredPRs[index]);

                                        // Get the insight for this PR to extract risk level
                                        final insight = prProvider
                                            .getInsightForPR(
                                              filteredPRs[index].number,
                                              repositoryId: filteredPRs[index]
                                                  .repositoryId,
                                            );

                                        // Navigate to premium insights screen
                                        // Pass the risk level from the dashboard to ensure consistency
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PremiumInsightsScreen(
                                                  pullRequest:
                                                      filteredPRs[index],
                                                  overrideRiskLevel:
                                                      insight?.riskLevel,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            );
                          }, childCount: filteredPRs.length + 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const ModernFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildRepositoryHeader() {
    return Consumer<GitHubProvider>(
      builder: (context, githubProvider, child) {
        if (!githubProvider.isConnected) {
          return _buildConnectPrompt();
        }

        // If connected but no specific repository selected, show "All Repositories" view
        if (githubProvider.selectedRepository == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.04),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.15),
                        AppTheme.primaryColor.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.dashboard,
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
                        'All Repositories',
                        style: AppTheme.premiumHeadingStyle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Viewing pull requests from all connected repositories',
                        style: AppTheme.premiumBodyStyle.copyWith(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${githubProvider.repositories.length} repos',
                    style: AppTheme.premiumBodyStyle.copyWith(
                      color: AppTheme.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final repo = githubProvider.selectedRepository!;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.04),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.15),
                      AppTheme.primaryColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_tree_rounded,
                  color: AppTheme.primaryColor,
                  size: 26,
                ),
              ),

              const SizedBox(width: 18),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repo.name,
                      style: AppTheme.premiumHeadingStyle.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            repo.fullName,
                            style: AppTheme.premiumBodyStyle.copyWith(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (repo.isPrivate)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.warningColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: AppTheme.warningColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Private',
                        style: AppTheme.premiumBodyStyle.copyWith(
                          color: AppTheme.warningColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectPrompt() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.link_outlined,
            size: 48,
            color: AppTheme.primaryColor.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Connect to GitHub',
            style: AppTheme.premiumHeadingStyle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your GitHub account to start tracking pull requests',
            style: AppTheme.premiumBodyStyle.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Consumer<PRProvider>(
      builder: (context, prProvider, child) {
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Active PRs',
                '${prProvider.pullRequests.where((pr) => pr.status == PRStatus.pending || pr.status == PRStatus.building).length}',
                Icons.pending_actions_outlined,
                AppTheme.primaryColor,
                0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Merged',
                '${prProvider.pullRequests.where((pr) => pr.status == PRStatus.merged).length}',
                Icons.check_circle_outline,
                AppTheme.successColor,
                1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Build Failed',
                '${prProvider.pullRequests.where((pr) => pr.status == PRStatus.buildFailed).length}',
                Icons.error_outline,
                AppTheme.errorColor,
                2,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    int index,
  ) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delayedAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              (index * 0.1).clamp(0.0, 0.8),
              (0.8 + (index * 0.1)).clamp(0.1, 1.0),
              curve: Curves.easeOutBack,
            ),
          ),
        );

        return Transform.translate(
          offset: Offset(0, (1 - delayedAnimation.value) * 30),
          child: Opacity(
            opacity: delayedAnimation.value.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: color.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    value,
                    style: AppTheme.premiumHeadingStyle.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: AppTheme.premiumBodyStyle.copyWith(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.dividerColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: AppTheme.premiumBodyStyle.copyWith(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search pull requests, authors, or titles...',
          hintStyle: AppTheme.premiumBodyStyle.copyWith(
            color: AppTheme.textHintColor,
            fontSize: 15,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: const Icon(
              Icons.search_outlined,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: Icon(
                    Icons.clear,
                    color: AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Consumer<PRProvider>(
      builder: (context, prProvider, child) {
        // Calculate status counts
        final statusCounts = <PRStatus, int>{};
        for (final status in PRStatus.values) {
          statusCounts[status] = prProvider.pullRequests
              .where((pr) => pr.status == status)
              .length;
        }

        return StatusFilterChips(
          selectedStatus: _statusFilter,
          onStatusChanged: (status) {
            setState(() {
              _statusFilter = status;
            });
          },
          statusCounts: statusCounts,
        );
      },
    );
  }

  Widget _buildSectionHeader() {
    return Consumer<PRProvider>(
      builder: (context, prProvider, child) {
        final filteredPRs = _getFilteredPRs(prProvider.pullRequests);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.list_alt_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Pull Requests',
                style: AppTheme.premiumHeadingStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.dividerColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${filteredPRs.length} ${filteredPRs.length == 1 ? 'result' : 'results'}',
                  style: AppTheme.premiumBodyStyle.copyWith(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.errorColor.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: AppTheme.premiumHeadingStyle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTheme.premiumBodyStyle.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPRsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.merge_outlined, size: 64, color: AppTheme.textHintColor),
          const SizedBox(height: 16),
          Text(
            'No pull requests found',
            style: AppTheme.premiumHeadingStyle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no pull requests matching your current filters',
            style: AppTheme.premiumBodyStyle.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<PullRequest> _getFilteredPRs(List<PullRequest> prs) {
    return prs.where((pr) {
      bool matchesSearch =
          _searchQuery.isEmpty ||
          pr.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          pr.author.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesStatus = _statusFilter == null || pr.status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }
}
