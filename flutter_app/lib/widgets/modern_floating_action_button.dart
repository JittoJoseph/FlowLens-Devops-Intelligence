import 'package:flutter/material.dart';
import '../config/premium_theme.dart';

class ModernFloatingActionButton extends StatefulWidget {
  const ModernFloatingActionButton({super.key});

  @override
  State<ModernFloatingActionButton> createState() =>
      _ModernFloatingActionButtonState();
}

class _ModernFloatingActionButtonState extends State<ModernFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown() {
    setState(() {
      _isPressed = true;
    });
    _controller.forward();
  }

  void _onTapUp() {
    setState(() {
      _isPressed = false;
    });
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: _isPressed ? 8 : 16,
                  offset: Offset(0, _isPressed ? 3 : 8),
                ),
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: _isPressed ? 12 : 32,
                  offset: Offset(0, _isPressed ? 6 : 16),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTapDown: (_) => _onTapDown(),
                onTapUp: (_) => _onTapUp(),
                onTapCancel: () => _onTapUp(),
                onTap: () {
                  // Show bottom sheet with quick actions
                  _showQuickActionsSheet(context);
                },
                borderRadius: BorderRadius.circular(30),
                splashColor: Colors.white.withValues(alpha: 0.2),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showQuickActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => _buildQuickActionsSheet(),
    );
  }

  Widget _buildQuickActionsSheet() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            'Quick Navigation',
            style: AppTheme.premiumHeadingStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // First row
                _buildActionRow([
                  _buildActionButton(
                    Icons.dashboard_outlined,
                    'Dashboard',
                    AppTheme.primaryColor,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/dashboard',
                        (route) => false,
                      );
                    },
                  ),
                  _buildActionButton(
                    Icons.account_tree_outlined,
                    'Repositories',
                    Colors.blue,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/repositories');
                    },
                  ),
                  _buildActionButton(
                    Icons.merge_outlined,
                    'Pull Requests',
                    Colors.green,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/pull-requests');
                    },
                  ),
                ]),

                const SizedBox(height: 12),

                // Second row
                _buildActionRow([
                  _buildActionButton(
                    Icons.insights_outlined,
                    'AI Insights',
                    Colors.orange,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/insights');
                    },
                  ),
                  _buildActionButton(
                    Icons.build_outlined,
                    'Pipeline',
                    Colors.purple,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/pipeline');
                    },
                  ),
                  _buildActionButton(
                    Icons.analytics_outlined,
                    'Analytics',
                    Colors.teal,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/analytics');
                    },
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildActionRow(List<Widget> actions) {
    return Row(
      children: actions
          .map((action) => Expanded(child: action))
          .expand(
            (widget) => [
              widget,
              if (widget != actions.last) const SizedBox(width: 12),
            ],
          )
          .toList(),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTheme.premiumBodyStyle.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
