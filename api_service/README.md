# FlowLens API Service: The AI & Governance Engine

The FlowLens API Service is the central intelligence and decision-making core of the FlowLens platform. This microservice transforms raw DevOps data into actionable insights, serving as the "brain" that powers our **Intelligent Transactional System**. It embodies the principles of `AI/ML-driven decision-making` and `Technical Innovation`.

## Key Features

- **Context-Aware AI Analysis**: Moves beyond simple metrics by analyzing actual code diffs with Google Gemini to generate nuanced risk assessments and recommendations.
- **Resilient Event Processing**: Employs a robust database polling mechanism that guarantees every event is processed, ensuring fault-tolerance even if the service restarts.
- **Real-Time Broadcasting**: Pushes live state updates via WebSockets, providing the real-time feedback loop essential for modern DevOps and observability.
- **Scalable, Repository-Centric Design**: Architected to manage and serve data for hundreds of repositories simultaneously, ensuring enterprise readiness.

## Getting Started

### Prerequisites

- Python 3.11+
- Access to the FlowLens YugabyteDB instance.
- A Google Gemini API key.

### Setup & Run

1.  **Clone and navigate to the service:** `git clone <repo> && cd api_service`
2.  **Create and activate a virtual environment:** `python -m venv venv && source venv/bin/activate`
3.  **Install dependencies:** `pip install -r requirements.txt`
4.  **Configure environment:** Copy `.env.example` to `.env` and fill in your `DATABASE_URL` and `GEMINI_API_KEY`.
5.  **Run the service:** `uvicorn app.main:app --reload`

The service and its interactive API docs will be available at `http://localhost:8000`.

## Documentation

- **[API Endpoints](./docs/api_endpoints.md)**: A complete reference for our RESTful API.
- **[WebSocket Guide](./docs/websockets.md)**: Details on the real-time communication protocol.
- **[AI Insights System](./docs/ai_insights.md)**: An overview of the AI-powered governance logic.
- **[Integration Guide](./docs/integration_guide.md)**: Guidelines for service-to-service interaction.

</br>

> ‎ 
> **</> Built by Mission Control | DevByZero 2025**
>
> *Defining the infinite possibilities in your DevOps pipeline.*
> ‎ 
