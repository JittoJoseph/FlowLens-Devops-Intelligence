# AI Insights System

The enhanced AI Insights system in v2.0 is a core feature of the FlowLens API Service. It leverages Google Gemini to analyze the actual content of file changes in a pull request, providing much deeper and more accurate insights than simple metadata analysis.

## 1. Files Changed Analysis

The system's intelligence comes from processing the `files_changed` JSON data, which is captured by the Ingestion Service from GitHub webhooks and stored in the `pull_requests` table. This data includes not just filenames but also line changes and the full diff patch.

**Example `files_changed` Snippet:**
```json
{
  "files_changed": [
    {
      "filename": "src/app/page.tsx",
      "status": "modified",
      "additions": 20,
      "deletions": 99,
      "changes": 119,
      "patch": "@@ -14,107 +14,28 @@ export default function Home() {\n   };\n \n   return (\n-    <div className=\"min-h-screen bg-gradient..."
    }
  ]
}
```

## 2. AI Processing Flow

The generation of an insight follows a clear, automated pipeline triggered by the database poller.

1.  **Trigger Detection:** The database poller identifies a new or updated `pull_requests` record with `processed = FALSE` and non-empty `files_changed` data.

2.  **Data Extraction:** The service parses the `files_changed` JSON, extracting key information like filenames, change statistics (`additions`, `deletions`), and the crucial `patch` data (the diff).

3.  **Enhanced Prompting:** A structured prompt is constructed and sent to the Google Gemini API. This prompt includes the extracted file analysis, asking the model to act as an expert code reviewer.

4.  **Insight Generation:** Gemini returns a structured response containing:
    - **Risk Assessment:** A classification of `low`, `medium`, or `high`.
    - **Summary:** A concise, one-sentence summary of the changes.
    - **Recommendation:** Actionable advice for the human reviewer (e.g., "Pay close attention to the state management logic in `userSlice.ts`").

5.  **Storage and Broadcasting:**
    - The generated insight is saved to the `insights` table in the database, linked to the correct repository and pull request.
    - The service's WebSocket manager is notified, which then broadcasts a state update to all connected clients.


</br>

> #
>
> **</> Built by Mission Control | DevByZero 2025**
>
> *Defining the infinite possibilities in your DevOps pipeline.*
> ##