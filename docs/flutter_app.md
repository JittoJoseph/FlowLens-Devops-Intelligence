# FlowLens Flutter Application Guide

## 1. Overview

FlowLens is a modern Flutter application that provides real-time visualization of DevOps workflows with AI-powered insights. The application is designed to showcase enterprise-grade mobile development practices with clean architecture and a premium user experience.

### Key Features

- **Real-time PR Tracking**: Live updates of pull request workflow status.
- **AI Insights**: Risk assessment and recommendations powered by the FlowLens API Service.
- **Premium UI/UX**: Modern minimalist design with a cream and brown color palette.
- **Responsive Design**: Optimized for mobile devices with smooth animations.
- **State Management**: Provider pattern for efficient data flow.
- **Real-time Updates**: WebSocket support for instant synchronization with the backend.

### Technical Stack

- **Framework**: Flutter
- **Language**: Dart
- **State Management**: Provider
- **HTTP Client**: `http` package
- **Real-time**: `web_socket_channel`

---

## 2. Architecture

FlowLens follows a layered architecture pattern with a clear separation of concerns:

```
├── Presentation Layer (Screens, Widgets, Theme)
├── Business Logic Layer (Providers, Services)
├── Data Layer (Models, Repositories)
└── Configuration (Routes, Constants)
```

---

## 3. Data Models

The application uses three core data models to represent the system's state.

### PullRequest Model
Represents a GitHub pull request with its associated workflow status.

### AIInsight Model
Represents AI-generated analysis and recommendations for a pull request.

### Repository Model
Contains metadata and statistics for a tracked GitHub repository.

---

## 4. State Management

The app uses the **Provider** pattern for state management, providing reactive data flow and efficient UI updates.

- **`GitHubProvider`**: Manages repository data and connection state.
- **`PRProvider`**: Manages the collection of pull requests, handles status updates, filtering, and real-time data from the WebSocket.

---

## 5. API and WebSocket Integration

FlowLens integrates with the FlowLens API Service for data retrieval and real-time updates.

### REST API Endpoints
The app primarily communicates with these endpoints:
- `GET /api/repositories`: To list all available repositories for selection.
- `GET /api/pull-requests?repository_id={uuid}`: To retrieve all pull requests for a selected repository.
- `GET /api/insights?repository_id={uuid}`: To get AI insights associated with the PRs.

### WebSocket Integration
For real-time updates, the app listens to a WebSocket stream.

```dart
// Connect to the WebSocket endpoint
WebSocketChannel channel = WebSocketChannel.connect(
  Uri.parse('wss://api.flowlens.dev/ws'),
);

// Listen for minimal state update messages
channel.stream.listen((data) {
  // On receiving a message, trigger a data refresh for the specific PR
  final update = jsonDecode(data);
  prProvider.handleRealtimeUpdate(update);
});
```
This ensures the UI reflects the latest status without constant polling from the client side. Refer to the **[API Service WebSocket Guide](../../api_service/docs/websockets.md)** for more details on the message format.

---

## 6. Development Setup

### Prerequisites
- Flutter SDK (latest stable version)
- An IDE such as VS Code or Android Studio

### Installation Steps
1.  **Clone the repository**: `git clone <repository_url>`
2.  **Navigate to the app folder**: `cd flutter_app`
3.  **Install dependencies**: `flutter pub get`
4.  **Run the application**: `flutter run`

</br>

> ‎ 
> **</> Built by Mission Control | DevByZero 2025**
>
> *Defining the infinite possibilities in your DevOps pipeline.*
> ‎ 
