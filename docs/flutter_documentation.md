# FlowLens Flutter Application Documentation

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Project Structure](#project-structure)
4. [Data Models](#data-models)
5. [State Management](#state-management)
6. [Screens](#screens)
7. [API Integration](#api-integration)
8. [Development Setup](#development-setup)
9. [Build and Deployment](#build-and-deployment)

## Overview

FlowLens is a modern Flutter application that provides real-time visualization of DevOps workflows with AI-powered insights. The application is designed for hackathon demonstration, showcasing enterprise-grade mobile development practices with clean architecture and premium user experience.

### Key Features

- **Real-time PR Tracking**: Live updates of pull request workflow status
- **AI Insights**: Risk assessment and recommendations powered by Gemini API
- **Premium UI/UX**: Modern minimalist design with cream and brown color palette
- **Responsive Design**: Optimized for mobile devices with smooth animations
- **State Management**: Provider pattern for efficient data flow
- **WebSocket Support**: Real-time updates from backend services

### Technical Stack

- **Framework**: Flutter
- **Language**: Dart
- **State Management**: Provider
- **HTTP Client**: Built-in http package
- **Real-time**: WebSocket Channel

## Architecture

FlowLens follows a layered architecture pattern with clear separation of concerns:

```
├── Presentation Layer
│   ├── Screens (UI Components)
│   ├── Widgets (Reusable Components)
│   └── Theme (Visual Design System)
├── Business Logic Layer
│   ├── Providers (State Management)
│   └── Services (API Communication)
├── Data Layer
│   ├── Models (Data Structures)
│   └── Repositories (Data Access)
└── Configuration
    ├── Routes
    └── Constants
```

### Design Principles

- **Single Responsibility**: Each class has one clear purpose
- **Dependency Injection**: Provider pattern for loose coupling
- **Immutable Data**: All models are immutable with copyWith methods
- **Reactive Programming**: Stream-based data flow for real-time updates

## Project Structure

```
lib/
├── main.dart                     # Application entry point
├── config/
│   └── premium_theme.dart        # Theme configuration
├── models/
│   ├── ai_insight.dart          # AI analysis data model
│   ├── pull_request.dart        # Pull request data model
│   └── repository.dart          # Repository data model
├── providers/
│   ├── github_provider.dart     # GitHub data management
│   ├── pr_provider.dart         # Pull request state management
│   └── theme_provider.dart      # Theme state management
├── screens/
│   ├── github_connect_screen.dart    # OAuth connection simulation
│   ├── minimalist_dashboard.dart     # Main dashboard view
│   ├── pr_details_screen.dart        # Detailed PR view
│   └── splash_screen.dart            # Application startup
├── services/                    # API communication services
├── utils/                       # Utility functions and helpers
└── widgets/
    └── app_sidebar.dart         # Navigation drawer component
```

## Data Models

### PullRequest Model

The core model representing a GitHub pull request with workflow tracking.

```dart
class PullRequest {
  final int number;
  final String title;
  final String description;
  final String author;
  final String authorAvatar;
  final String commitSha;
  final String repositoryName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PRStatus status;
  final List<String> filesChanged;
  final int additions;
  final int deletions;
  final String branchName;
  final bool isDraft;
}
```

**Status Enumeration:**

- `pending`: Initial state
- `building`: CI/CD pipeline running
- `buildPassed`: Build completed successfully
- `buildFailed`: Build failed
- `approved`: Code review approved
- `merged`: Pull request merged
- `closed`: Pull request closed without merge

### AIInsight Model

Represents AI-generated analysis and recommendations for pull requests.

```dart
class AIInsight {
  final String id;
  final int prNumber;
  final String commitSha;
  final RiskLevel riskLevel;
  final String summary;
  final String recommendation;
  final DateTime createdAt;
  final List<String> keyChanges;
  final double confidenceScore;
}
```

**Risk Level Enumeration:**

- `low`: Minimal impact changes
- `medium`: Moderate risk requiring review
- `high`: High-impact changes needing careful assessment

### Repository Model

Contains GitHub repository metadata and statistics.

```dart
class Repository {
  final String name;
  final String fullName;
  final String description;
  final String owner;
  final String ownerAvatar;
  final bool isPrivate;
  final String defaultBranch;
  final int openPRs;
  final int totalPRs;
  final DateTime lastActivity;
  final List<String> languages;
  final int stars;
  final int forks;
}
```

## State Management

FlowLens uses the Provider pattern for state management, providing reactive data flow and efficient UI updates.

### GitHubProvider

Manages repository data and GitHub connection state.

**Key Features:**

- Repository information management
- Connection status tracking
- Demo data simulation for hackathon

**Usage:**

```dart
Consumer<GitHubProvider>(
  builder: (context, githubProvider, child) {
    return Text(githubProvider.currentRepository?.name ?? 'No repository');
  },
)
```

### PRProvider

Handles pull request data and workflow status updates.

**Key Features:**

- Pull request collection management
- Status filtering and sorting
- Real-time updates from WebSocket
- AI insights integration

**Methods:**

- `loadPullRequests()`: Fetch PR data from API
- `updatePRStatus()`: Update individual PR status
- `filterByStatus()`: Filter PRs by workflow status
- `refreshData()`: Force data refresh

## Screens

### Splash Screen

Application startup screen with FlowLens branding and initialization logic.

**Features:**

- App logo and branding display
- Loading animations
- Initial data loading
- Navigation to main application

### GitHub Connect Screen

Simulates GitHub OAuth connection for hackathon demonstration.

**Features:**

- Connect button with loading states
- Success animation
- Error handling simulation
- Navigation to dashboard upon connection

### Minimalist Dashboard

Main application screen displaying pull requests with clean, modern design.

**Features:**

- CustomScrollView for smooth scrolling
- Pull request list with status filtering
- AI insights preview
- Real-time status updates
- Navigation to detailed views

**Layout:**

- Header with repository information
- Filter controls for PR status
- Scrollable PR list
- Floating action button for quick actions

### PR Details Screen

Detailed view of individual pull requests with workflow visualization.

**Features:**

- Complete PR information display
- Workflow progress indicator
- AI insights and recommendations
- File changes summary
- Action buttons for common operations

## API Integration

FlowLens is designed to integrate with backend services through REST APIs and WebSocket connections.

### REST API Endpoints

**Base URL**: `https://api.flowlens.dev` (placeholder)

**Endpoints:**

- `GET /api/prs`: Retrieve pull requests with status and insights
- `GET /api/insights/{pr_number}`: Get AI insights for specific PR
- `GET /api/repository`: Get repository information
- `PUT /api/prs/{pr_number}/status`: Update PR status

### WebSocket Integration

Real-time updates for live workflow visualization:

```dart
WebSocketChannel channel = WebSocketChannel.connect(
  Uri.parse('wss://api.flowlens.dev/ws'),
);

channel.stream.listen((data) {
  final update = jsonDecode(data);
  prProvider.handleRealtimeUpdate(update);
});
```

### Data Serialization

All models implement `toJson()` and `fromJson()` methods for API communication:

```dart
// Serialization
final jsonData = pullRequest.toJson();

// Deserialization
final pullRequest = PullRequest.fromJson(jsonData);
```

## Development Setup

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK (included with Flutter)
- IDE: VS Code or Android Studio
- Git for version control

### Installation Steps

1. **Clone Repository**:

   ```bash
   git clone https://github.com/DevOps-Malayalam/mission-control.git
   cd mission-control/flutter_app
   ```

2. **Install Dependencies**:

   ```bash
   flutter pub get
   ```

3. **Run Application**:
   ```bash
   flutter run
   ```

### Development Commands

**Code Generation**:

```bash
flutter packages pub run build_runner build
```

**Testing**:

```bash
flutter test
```

**Code Analysis**:

```bash
flutter analyze
```

**Format Code**:

```bash
dart format .
```

### Environment Configuration

Create environment-specific configuration files for API endpoints and settings.

## Build and Deployment

### Build Configuration

**Android Release Build**:

```bash
flutter build apk --release
```

**iOS Release Build**:

```bash
flutter build ios --release
```

**Web Build**:

```bash
flutter build web --release
```

### App Icons

The application uses flutter_launcher_icons for platform-specific icon generation.

### Performance Optimization

**Build Optimizations**:

- Tree shaking for reduced bundle size
- Code splitting for web deployment
- Asset optimization for faster loading

**Runtime Optimizations**:

- Efficient list rendering with ListView.builder
- Image caching for avatars and assets
- Debounced search and filtering

### Deployment Targets

**Mobile Platforms**:

- Android (API level 21+)
- iOS (iOS 11.0+)

**Web Platform**:

- Progressive Web App (PWA) support
- Responsive design for desktop and mobile browsers
