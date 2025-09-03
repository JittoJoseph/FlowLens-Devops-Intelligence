import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/premium_theme.dart';
import '../providers/github_provider.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.cardColor,
      elevation: 0,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.lens,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'FlowLens',
                      style: AppTheme.premiumHeadingStyle.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'AI-Powered DevOps',
                      style: AppTheme.premiumBodyStyle.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Menu Items
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildMenuItem(
                          Icons.dashboard_outlined,
                          'Dashboard',
                          'Overview & insights',
                          _isDashboardActive(context),
                          () {
                            Navigator.pop(context);
                            if (!_isDashboardActive(context)) {
                              Navigator.pushReplacementNamed(
                                context,
                                '/dashboard',
                              );
                            }
                          },
                        ),
                        _buildMenuItem(
                          Icons.account_tree_outlined,
                          'Repositories',
                          'Manage repos',
                          ModalRoute.of(context)?.settings.name ==
                              '/repositories',
                          () {
                            Navigator.pop(context);
                            if (ModalRoute.of(context)?.settings.name !=
                                '/repositories') {
                              Navigator.pushReplacementNamed(
                                context,
                                '/repositories',
                              );
                            }
                          },
                        ),
                        _buildMenuItem(
                          Icons.merge_outlined,
                          'Pull Requests',
                          'Review & merge',
                          ModalRoute.of(context)?.settings.name ==
                              '/pull-requests',
                          () {
                            Navigator.pop(context);
                            if (ModalRoute.of(context)?.settings.name !=
                                '/pull-requests') {
                              Navigator.pushReplacementNamed(
                                context,
                                '/pull-requests',
                              );
                            }
                          },
                        ),
                        _buildMenuItem(
                          Icons.insights_outlined,
                          'AI Insights',
                          'View analysis & reports',
                          ModalRoute.of(context)?.settings.name == '/insights',
                          () {
                            Navigator.pop(context);
                            if (ModalRoute.of(context)?.settings.name !=
                                '/insights') {
                              Navigator.pushReplacementNamed(
                                context,
                                '/insights',
                              );
                            }
                          },
                        ),
                        _buildMenuItem(
                          Icons.build_outlined,
                          'CI/CD Pipeline',
                          'Build & deploy',
                          ModalRoute.of(context)?.settings.name == '/pipeline',
                          () {
                            Navigator.pop(context);
                            if (ModalRoute.of(context)?.settings.name !=
                                '/pipeline') {
                              Navigator.pushReplacementNamed(
                                context,
                                '/pipeline',
                              );
                            }
                          },
                        ),
                        _buildMenuItem(
                          Icons.analytics_outlined,
                          'Analytics',
                          'Performance metrics',
                          ModalRoute.of(context)?.settings.name == '/analytics',
                          () {
                            Navigator.pop(context);
                            if (ModalRoute.of(context)?.settings.name !=
                                '/analytics') {
                              Navigator.pushReplacementNamed(
                                context,
                                '/analytics',
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Divider(
                            color: AppTheme.dividerColor.withValues(alpha: 0.3),
                            thickness: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildMenuItem(
                          Icons.person_outline,
                          'Profile',
                          'Account settings',
                          false,
                          () {
                            Navigator.pop(context);
                            // TODO: Navigate to profile
                          },
                        ),
                        _buildMenuItem(
                          Icons.settings_outlined,
                          'Settings',
                          'App preferences',
                          false,
                          () {
                            Navigator.pop(context);
                            // TODO: Navigate to settings
                          },
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.dividerColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Consumer<GitHubProvider>(
                builder: (context, githubProvider, child) {
                  if (githubProvider.isConnected) {
                    return _buildMenuItem(
                      Icons.logout,
                      'Sign Out',
                      'Disconnect GitHub',
                      false,
                      () {
                        Navigator.pop(context);
                        githubProvider.disconnect();
                        // Navigate back to GitHub connect screen
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/connect',
                          (route) => false,
                        );
                      },
                      isDestructive: true,
                    );
                  } else {
                    return _buildMenuItem(
                      Icons.link,
                      'Connect GitHub',
                      'Link your account',
                      false,
                      () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/connect');
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    String subtitle,
    bool isSelected,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final primaryColor = isDestructive
        ? AppTheme.errorColor
        : AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                        : primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? AppTheme.primaryColor : primaryColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.premiumBodyStyle.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textPrimaryColor,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTheme.premiumBodyStyle.copyWith(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to check if we're currently on a dashboard screen
  bool _isDashboardActive(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name;

    // Check for named dashboard route
    if (routeName == '/dashboard') {
      return true;
    }

    // Check if the current widget tree contains a DashboardScreen
    // This handles cases where we navigate via MaterialPageRoute
    try {
      final currentRoute = ModalRoute.of(context);
      if (currentRoute?.settings.arguments != null) {
        final args = currentRoute!.settings.arguments as Map<String, dynamic>?;
        // If route has repositoryId argument, it's likely a dashboard
        if (args?.containsKey('repositoryId') == true) {
          return true;
        }
      }
    } catch (e) {
      // If we can't determine from arguments, fall back to route name check
    }

    return false;
  }
}
