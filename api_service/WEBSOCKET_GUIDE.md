# WebSocket Implementation Summary

## Overview

The API service WebSocket has been completely redesigned to send **minimal PR state updates** specifically for Flutter real-time integration.

## WebSocket Endpoint

- **URL**: `ws://localhost:8000/ws` (or your deployment URL)
- **Purpose**: Real-time PR state updates only
- **Protocol**: Standard WebSocket with JSON messages

## Message Format

The WebSocket now sends **only essential data** for efficient Flutter integration:

```json
{
  "repo_id": "uuid-of-repository",
  "pr_number": 123,
  "state": "open"
}
```

### Fields:

- `repo_id`: Repository identifier (UUID string)
- `pr_number`: Pull request number (integer)
- `state`: Current PR state (`"open"`, `"closed"`, `"merged"`, etc.)

## When Messages Are Sent

WebSocket messages are broadcasted when:

1. **New PR created** - Initial state broadcast
2. **PR status updated** - State changes (approved, merged, closed)
3. **Pipeline status changed** - CI/CD updates affecting the PR
4. **Insights generated** - AI analysis completed

## Flutter Integration Guide

### 1. Connect to WebSocket

```dart
final channel = WebSocketChannel.connect(
  Uri.parse('ws://your-api-url/ws'),
);
```

### 2. Listen for State Updates

```dart
channel.stream.listen((message) {
  final data = jsonDecode(message);

  // Extract minimal state data
  final repoId = data['repo_id'];
  final prNumber = data['pr_number'];
  final state = data['state'];

  // Update your Flutter state management
  updatePRState(repoId, prNumber, state);
});
```

### 3. Handle Connection Management

```dart
// Handle disconnections
channel.stream.handleError((error) {
  print('WebSocket error: $error');
  // Implement reconnection logic
});

// Close when done
channel.sink.close();
```

## Benefits of This Approach

1. **Minimal bandwidth** - Only essential data transmitted
2. **Real-time updates** - Instant state synchronization
3. **Simple integration** - Easy to parse and handle in Flutter
4. **Efficient** - No unnecessary data like file changes or insights
5. **Focused** - Only PR state updates, nothing else

## Architecture

- **Polling-based**: API service polls database every 2 seconds for changes
- **Event-driven**: WebSocket broadcasts triggered by database updates
- **Stateless**: Each message is independent, no session state required
- **Resilient**: Handles disconnections gracefully

## Testing

Use the included `test_websocket.py` script to test the WebSocket connection:

```bash
cd api_service
python test_websocket.py
```

## Implementation Details

- **File**: `app/services/websocket_manager.py`
- **Method**: `broadcast_pr_state_update(repo_id, pr_number)`
- **Trigger**: Called from `event_processor.py` when PR changes detected
- **Error Handling**: Automatic cleanup of disconnected clients

This simplified approach ensures Flutter gets exactly what it needs for real-time PR state updates without any unnecessary overhead.
