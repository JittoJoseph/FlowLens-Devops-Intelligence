import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/premium_theme.dart';
import '../providers/github_provider.dart';

class GitHubConnectScreen extends StatefulWidget {
  const GitHubConnectScreen({super.key});

  @override
  State<GitHubConnectScreen> createState() => _GitHubConnectScreenState();
}

class _GitHubConnectScreenState extends State<GitHubConnectScreen>
    with TickerProviderStateMixin {
  late AnimationController _buttonController;
  late AnimationController _contentController;
  late Animation<double> _buttonAnimation;
  late Animation<double> _contentAnimation;
  bool _servicesHealthy = false;
  bool _checkingHealth = true;

  @override
  void initState() {
    super.initState();

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.elasticOut),
    );

    _contentAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeInOut),
    );

    _startAnimations();
    _performBackgroundHealthChecks();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _contentController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _buttonController.forward();
  }

  void _performBackgroundHealthChecks() async {
    // Ensure this runs after the initial build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final githubProvider = Provider.of<GitHubProvider>(
        context,
        listen: false,
      );

      await githubProvider.checkServicesHealth();

      // Check if the widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _servicesHealthy = githubProvider.servicesHealthy;
          _checkingHealth = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _buttonController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.premiumGradientDecoration,
        child: SafeArea(
          child: Consumer<GitHubProvider>(
            builder: (context, gitHubProvider, child) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Spacer(),

                    // Header Section
                    FadeTransition(
                      opacity: _contentAnimation,
                      child: Column(
                        children: [
                          // Premium Icon Container
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.code_outlined,
                              size: 50,
                              color: AppTheme.primaryColor,
                            ),
                          ),

                          const SizedBox(height: 32),

                          Text(
                            'Connect to GitHub',
                            style: AppTheme.premiumHeadingStyle,
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),

                          Text(
                            'Access your repositories and enable\nreal-time DevOps insights',
                            style: AppTheme.premiumSubheadingStyle,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Features List
                    FadeTransition(
                      opacity: _contentAnimation,
                      child: Container(
                        decoration: AppTheme.premiumCardDecoration,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildFeatureItem(
                              Icons.analytics_outlined,
                              'AI-Powered Analysis',
                              'Get intelligent insights on your pull requests',
                            ),
                            const SizedBox(height: 20),
                            _buildFeatureItem(
                              Icons.timeline_outlined,
                              'Real-time Tracking',
                              'Monitor your DevOps workflow in real-time',
                            ),
                            const SizedBox(height: 20),
                            _buildFeatureItem(
                              Icons.security_outlined,
                              'Risk Assessment',
                              'Automatic risk evaluation for every change',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Connect Button
                    AnimatedBuilder(
                      animation: _buttonAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _buttonAnimation.value,
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: gitHubProvider.isConnecting
                                ? _buildLoadingButton()
                                : _buildConnectButton(context, gitHubProvider),
                          ),
                        );
                      },
                    ),

                    // Health status indicator
                    if (!_checkingHealth) ...[
                      const SizedBox(height: 12),
                      _buildHealthStatusIndicator(),
                    ],

                    if (gitHubProvider.hasError) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.errorColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppTheme.errorColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                gitHubProvider.errorMessage ??
                                    'Connection failed',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.errorColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),

                    // Footer Note
                    FadeTransition(
                      opacity: _contentAnimation,
                      child: Text(
                        'Demo Mode: No authentication required',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textHintColor,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textTertiaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectButton(BuildContext context, GitHubProvider provider) {
    final isEnabled = _servicesHealthy && !_checkingHealth;

    return ElevatedButton.icon(
      onPressed: isEnabled ? () => _handleConnect(context, provider) : null,
      icon: Icon(
        _checkingHealth
            ? Icons.health_and_safety_outlined
            : _servicesHealthy
            ? Icons.link_outlined
            : Icons.warning_outlined,
        size: 24,
      ),
      label: Text(
        _checkingHealth
            ? 'Checking Services...'
            : _servicesHealthy
            ? 'Connect to GitHub'
            : 'Services Unavailable',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: isEnabled ? Colors.white : Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled
            ? AppTheme.primaryColor
            : AppTheme.textHintColor,
        foregroundColor: Colors.white,
        elevation: isEnabled ? 12 : 4,
        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildHealthStatusIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _servicesHealthy
            ? AppTheme.successColor.withValues(alpha: 0.1)
            : AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _servicesHealthy
              ? AppTheme.successColor.withValues(alpha: 0.2)
              : AppTheme.errorColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _servicesHealthy ? Icons.check_circle_outline : Icons.error_outline,
            color: _servicesHealthy
                ? AppTheme.successColor
                : AppTheme.errorColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _servicesHealthy
                  ? 'Backend services are healthy and ready'
                  : 'Backend services are currently unavailable',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _servicesHealthy
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 16),
          Text(
            'Connecting...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _handleConnect(BuildContext context, GitHubProvider provider) async {
    await provider.connectToGitHub();

    if (provider.isConnected && mounted) {
      if (context.mounted) {
        // Navigate to repositories screen instead of dashboard
        Navigator.pushReplacementNamed(context, '/repositories');
      }
    }
  }
}
