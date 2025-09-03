import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/repository.dart';
import '../models/pull_request.dart';
import '../models/ai_insight.dart';
import '../models/pipeline_run.dart';

class ApiService {
  static const String _baseUrl = 'https://flowlens-api-service.onrender.com';
  static const String _ingestionBaseUrl =
      'https://devbyzero-mission-control.onrender.com';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Debug logging helper
  static void _debugLog(String message) {
    if (kDebugMode) {
      print('[ApiService] $message');
    }
  }

  // Health check for API service
  static Future<bool> isApiServiceHealthy() async {
    try {
      _debugLog('Checking API service health at: $_baseUrl/');

      final response = await http
          .get(Uri.parse('$_baseUrl/'), headers: _headers)
          .timeout(
            const Duration(seconds: 15),
          ); // Increased timeout for release

      _debugLog('API service response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          bool isHealthy = data['status'] == 'online';
          _debugLog('API service health result: $isHealthy');
          return isHealthy;
        } catch (e) {
          _debugLog('API service JSON parsing error: $e');
          // Handle case where Render serves HTML during wake-up
          // Check if it's a simple text response that indicates health
          if (response.body.toLowerCase().contains('healthy') ||
              response.body.toLowerCase().contains('online') ||
              response.body.toLowerCase().contains('ok')) {
            _debugLog('API service appears healthy based on text content');
            return true;
          }
          return false;
        }
      }
      _debugLog('API service unhealthy - status code: ${response.statusCode}');
      return false;
    } catch (e) {
      _debugLog('API service health check error: $e');
      return false;
    }
  }

  // Health check for ingestion service
  static Future<bool> isIngestionServiceHealthy() async {
    try {
      final response = await http
          .get(Uri.parse('$_ingestionBaseUrl/health'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          bool isHealthy = data['status'] == 'healthy';
          return isHealthy;
        } catch (e) {
          // Handle case where Render serves HTML during wake-up
          // Check if it's a simple text response that indicates health
          if (response.body.toLowerCase().contains('healthy') ||
              response.body.toLowerCase().contains('online') ||
              response.body.toLowerCase().contains('ok')) {
            return true;
          }
          return false;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Comprehensive health check with retry logic
  static Future<bool> performHealthChecks() async {
    const int maxRetries = 3; // Reduced from 5 to 3 for faster response
    const Duration retryDelay = Duration(
      seconds: 2,
    ); // Reduced from 3 to 2 seconds

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final apiHealthy = await isApiServiceHealthy();

      // For now, only require API service to be healthy due to CORS issues with ingestion service from web
      // In production, both should be checked
      if (apiHealthy) {
        return true;
      }

      if (attempt < maxRetries) {
        await Future.delayed(retryDelay);
      }
    }

    return false;
  }

  // Get all repositories
  static Future<List<Repository>> getRepositories() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/repositories'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Repository.fromApiJson(json)).toList();
      } else {
        throw HttpException(
          'Failed to load repositories: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get pull requests for a repository
  static Future<List<PullRequest>> getPullRequests({
    String? repositoryId,
  }) async {
    try {
      String url = '$_baseUrl/api/pull-requests';
      if (repositoryId != null) {
        url += '?repository_id=$repositoryId';
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => PullRequest.fromApiJson(json)).toList();
      } else {
        throw HttpException(
          'Failed to load pull requests: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get AI insights for a repository
  static Future<List<AIInsight>> getInsights({String? repositoryId}) async {
    try {
      String url = '$_baseUrl/api/insights';
      if (repositoryId != null) {
        url += '?repository_id=$repositoryId';
      }

      _debugLog('Fetching insights from: $url');
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        _debugLog('Successfully received insights response');
        final List<dynamic> data = json.decode(response.body);

        final insights = <AIInsight>[];
        for (final item in data) {
          try {
            final insight = AIInsight.fromApiJson(item);
            insights.add(insight);
          } catch (e) {
            _debugLog('Error parsing insight: $e');
            // Continue with other insights
          }
        }

        _debugLog('Successfully parsed ${insights.length} insights');
        return insights;
      } else {
        throw HttpException('Failed to load insights: ${response.statusCode}');
      }
    } catch (e) {
      _debugLog('Error in getInsights: $e');
      rethrow;
    }
  }

  // Get AI insights for a specific PR
  static Future<List<AIInsight>> getInsightsForPR(
    int prNumber, {
    String? repositoryId,
  }) async {
    try {
      String url = '$_baseUrl/api/insights/$prNumber';
      if (repositoryId != null) {
        url += '?repository_id=$repositoryId';
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => AIInsight.fromApiJson(json)).toList();
      } else {
        throw HttpException(
          'Failed to load PR insights: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get pipeline runs for a repository
  static Future<List<PipelineRun>> getPipelines({String? repositoryId}) async {
    try {
      String url = '$_baseUrl/api/pipelines';
      if (repositoryId != null) {
        url += '?repository_id=$repositoryId';
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => PipelineRun.fromApiJson(json)).toList();
      } else {
        throw HttpException('Failed to load pipelines: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
