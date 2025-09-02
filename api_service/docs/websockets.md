# WebSocket Guide

The API service provides real-time updates to connected clients using WebSockets. The implementation is designed to be minimal and efficient, specifically for the Flutter application's needs.

## Connection

- **URL**: `ws://localhost:8000/ws` (or your deployment URL)
- **Protocol**: Standard WebSocket with JSON messages

## Message Format

To minimize bandwidth and simplify client-side logic, the WebSocket sends only the essential identifiers and state for a pull request. The client is expected to use this message as a trigger to re-fetch the full PR details via the REST API if needed.

```json
{
  "repo_id": "uuid-of-repository",
  "pr_number": 123,
  "state": "open"
}
```

### Fields

- `repo_id` (string): The unique UUID of the repository where the change occurred.
- `pr_number` (integer): The pull request number.
- `state` (string): The current high-level state of the PR (e.g., `"open"`, `"closed"`, `"merged"`).

## Broadcast Triggers

A WebSocket message is broadcasted whenever the API service's poller detects and processes a change related to a pull request, including:
- A new PR is created.
- A PR's status or details are updated.
- A pipeline run associated with a PR changes state.
- A new AI insight is generated for a PR.

## Client Integration (Flutter Example)

1.  **Connect to the WebSocket:**
    ```dart
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://your-api-url/ws'),
    );
    ```

2.  **Listen for State Updates:**
    ```dart
    channel.stream.listen((message) {
      final data = jsonDecode(message);
      final repoId = data['repo_id'];
      final prNumber = data['pr_number'];

      // Use this as a trigger to refresh data for the specific PR
      // e.g., refetch from /api/pull-requests?repository_id={repoId}
      prProvider.refreshSinglePR(repoId, prNumber);
    });
    ```
This lightweight approach ensures the UI stays responsive and only fetches detailed data when necessary.