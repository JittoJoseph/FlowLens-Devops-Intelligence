import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/premium_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/github_provider.dart';
import 'providers/pr_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/github_connect_screen.dart';
import 'screens/minimalist_dashboard.dart';
import 'screens/pr_details_screen.dart';

void main() {
  runApp(const FlowLensApp());
}

class FlowLensApp extends StatelessWidget {
  const FlowLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => GitHubProvider()),
        ChangeNotifierProvider(create: (_) => PRProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'FlowLens',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/connect': (context) => const GitHubConnectScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/pr-details': (context) => const PRDetailsScreen(),
            },
          );
        },
      ),
    );
  }
}
