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
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
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
            'Quick Actions',
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
                _buildActionRow([
                  _buildActionButton(
                    Icons.add_circle_outline,
                    'Create PR',
                    AppTheme.primaryColor,
                    () {
                      Navigator.pop(context);
                      // TODO: Navigate to create PR
                    },
                  ),
                  _buildActionButton(
                    Icons.rate_review_outlined,
                    'Review Queue',
                    AppTheme.successColor,
                    () {
                      Navigator.pop(context);
                      // TODO: Navigate to review queue
                    },
                  ),
                ]),

                const SizedBox(height: 16),

                _buildActionRow([
                  _buildActionButton(
                    Icons.insights_outlined,
                    'Analytics',
                    AppTheme.warningColor,
                    () {
                      Navigator.pop(context);
                      // TODO: Navigate to analytics
                    },
                  ),
                  _buildActionButton(
                    Icons.sync_outlined,
                    'Sync Data',
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                    () {
                      Navigator.pop(context);
                      // TODO: Sync data
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTheme.premiumBodyStyle.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
