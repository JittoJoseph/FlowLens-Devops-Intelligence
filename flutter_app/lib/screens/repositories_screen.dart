import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/premium_theme.dart';
import '../providers/github_provider.dart';
import '../widgets/simple_app_header.dart';
import '../widgets/app_sidebar.dart';
import '../models/repository.dart';
import 'minimalist_dashboard.dart';

class RepositoriesScreen extends StatefulWidget {
  const RepositoriesScreen({super.key});

  @override
  State<RepositoriesScreen> createState() => _RepositoriesScreenState();
}

class _RepositoriesScreenState extends State<RepositoriesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();

    // Schedule the repository loading after the build process is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRepositories();
    });
  }

  void _loadRepositories() async {
    final githubProvider = Provider.of<GitHubProvider>(context, listen: false);
    await githubProvider.loadRepositories();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: const AppSidebar(),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            SimpleAppHeader(onRefresh: _loadRepositories),

            // Content
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Header section
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 16),
                        _buildPageHeader(),
                        const SizedBox(height: 24),
                        _buildSearchBar(),
                        const SizedBox(height: 20),
                      ]),
                    ),
                  ),

                  // Repositories list
                  Consumer<GitHubProvider>(
                    builder: (context, githubProvider, child) {
                      if (githubProvider.isLoading) {
                        return const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (githubProvider.errorMessage != null) {
                        return SliverFillRemaining(
                          child: _buildErrorState(githubProvider.errorMessage!),
                        );
                      }

                      final filteredRepos = _getFilteredRepositories(
                        githubProvider.repositories,
                      );

                      if (filteredRepos.isEmpty) {
                        return SliverFillRemaining(child: _buildEmptyState());
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            if (index == filteredRepos.length) {
                              return const SizedBox(height: 100);
                            }

                            return AnimatedBuilder(
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
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildRepositoryCard(
                                      filteredRepos[index],
                                      githubProvider,
                                    ),
                                  ),
                                );
                              },
                            );
                          }, childCount: filteredRepos.length + 1),
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
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.15),
                  AppTheme.primaryColor.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.account_tree_outlined,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Repositories',
                  style: AppTheme.premiumHeadingStyle.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a repository to view its pull requests and insights',
                  style: AppTheme.premiumBodyStyle.copyWith(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          hintText: 'Search repositories by name, owner, or language...',
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

  Widget _buildRepositoryCard(Repository repository, GitHubProvider provider) {
    final isSelected = provider.selectedRepository?.id == repository.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onRepositorySelected(repository, provider),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : AppTheme.dividerColor.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.15)
                    : AppTheme.primaryColor.withValues(alpha: 0.08),
                blurRadius: isSelected ? 20 : 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.04),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.15),
                          AppTheme.primaryColor.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.folder_outlined,
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
                          repository.name,
                          style: AppTheme.premiumHeadingStyle.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          repository.fullName,
                          style: AppTheme.premiumBodyStyle.copyWith(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (repository.isPrivate)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Private',
                        style: TextStyle(
                          color: AppTheme.warningColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),

              if (repository.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  repository.description,
                  style: AppTheme.premiumBodyStyle.copyWith(
                    color: AppTheme.textTertiaryColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 16),

              // Stats row
              Row(
                children: [
                  _buildStatChip(
                    Icons.merge_outlined,
                    '${repository.openPRs} Open',
                    AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    Icons.star_outline,
                    '${repository.stars}',
                    AppTheme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    Icons.fork_right_outlined,
                    '${repository.forks}',
                    AppTheme.secondaryColor,
                  ),
                  const Spacer(),
                  if (repository.languages.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        repository.languages.first,
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 64,
            color: AppTheme.textHintColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No repositories found',
            style: AppTheme.premiumHeadingStyle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to GitHub to see your repositories',
            style: AppTheme.premiumBodyStyle.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
            onPressed: _loadRepositories,
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

  List<Repository> _getFilteredRepositories(List<Repository> repositories) {
    if (_searchQuery.isEmpty) return repositories;

    return repositories.where((repo) {
      final query = _searchQuery.toLowerCase();
      return repo.name.toLowerCase().contains(query) ||
          repo.fullName.toLowerCase().contains(query) ||
          repo.owner.toLowerCase().contains(query) ||
          repo.languages.any((lang) => lang.toLowerCase().contains(query));
    }).toList();
  }

  void _onRepositorySelected(Repository repository, GitHubProvider provider) {
    provider.selectRepository(repository);

    // Navigate to repository dashboard
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DashboardScreen(),
        settings: RouteSettings(arguments: {'repositoryId': repository.id}),
      ),
    );
  }
}
