import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/premium_theme.dart';
import '../providers/github_provider.dart';

class SimpleAppHeader extends StatelessWidget {
  final VoidCallback? onRefresh;

  const SimpleAppHeader({super.key, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(
          bottom: BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Menu Button
          Builder(
            builder: (context) => Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => Scaffold.of(context).openDrawer(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.menu,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // App Branding
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lens_outlined,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'FlowLens',
                      style: AppTheme.premiumHeadingStyle.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Consumer<GitHubProvider>(
                  builder: (context, githubProvider, child) {
                    if (githubProvider.isConnected &&
                        githubProvider.selectedRepository != null) {
                      return Text(
                        githubProvider.selectedRepository!.name,
                        style: AppTheme.premiumBodyStyle.copyWith(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }
                    return Text(
                      'DevOps Dashboard',
                      style: AppTheme.premiumBodyStyle.copyWith(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Refresh Button
          if (onRefresh != null)
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onRefresh,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.refresh,
                    color: AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
