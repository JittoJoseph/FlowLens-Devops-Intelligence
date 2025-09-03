# API Endpoints (v2.0)

The FlowLens API service provides a set of RESTful endpoints for accessing repository, pull request, pipeline, and insight data. All endpoints are designed with a repository-centric architecture.

**Interactive Documentation:**
- **Swagger UI:** Available at `http://localhost:8000/docs`
- **ReDoc:** Available at `http://localhost:8000/redoc`

---

## Core Resource Endpoints

#### `GET /api/repositories`
- **Description:** Returns a list of all repositories tracked by the system.
- **Features:** Provides complete metadata, statistics, and recent activity tracking for each repository.
- **Response:** An array of repository objects.

#### `GET /api/pull-requests`
- **Description:** Returns pull requests, with optional filtering by repository.
- **Query Parameters:**
  - `repository_id` (UUID, optional): If provided, filters pull requests to the specified repository.
- **Response:** An array of pull request objects, including complete metadata and file change information.

#### `GET /api/pipelines`
- **Description:** Returns pipeline run statuses, with optional filtering by repository.
- **Query Parameters:**
  - `repository_id` (UUID, optional): If provided, filters pipeline runs to the specified repository.
- **Response:** An array of pipeline objects with detailed status progression.

#### `GET /api/insights`
- **Description:** Returns AI-generated insights, with optional filtering by repository.
- **Query Parameters:**
  - `repository_id` (UUID, optional): If provided, filters insights to the specified repository.
- **Response:** An array of insight objects, including risk assessments and recommendations.

#### `GET /api/insights/{pr_number}`
- **Description:** Returns the historical insights for a specific pull request within a repository.
- **Query Parameters:**
  - `repository_id` (UUID, **required**): Specifies the repository to query within.
- **Response:** An array of all insights generated for the specified PR, ordered chronologically.

---

## Legacy Compatibility Endpoints

To ensure backward compatibility with older clients, the following v1.0 endpoints are maintained.

#### `GET /api/prs` (Legacy)
- **Description:** Provides aggregated pull request data formatted for existing v1.0 Flutter models.
- **Features:** Maintains backward compatibility with single-repository clients.

#### `GET /api/repository` (Legacy)
- **Description:** Returns metadata for a single, primary repository.
- **Features:** Supports legacy clients that are not multi-repository aware.


</br>

> #
>
> **</> Built by Mission Control | DevByZero 2025**
>
> *Defining the infinite possibilities in your DevOps pipeline.*
> ##