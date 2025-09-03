# Local Development Guide

This guide provides detailed instructions for developers who need to run and debug the backend services **natively** (outside of Docker) on their local machine.

For running the entire backend stack at once, please refer to the **[Docker Compose instructions in the main README](../../README.md#-running-the-entire-backend-with-docker)**.

## Prerequisites

Before running any service, ensure you have completed the following setup steps:

1.  **Database Ready**: Your YugabyteDB instance must be running and accessible. The schema should be applied as described in the **[Database Guide](./database.md)**.

2.  **Environment Configuration**:
    - Copy the root `.env.example` file to `.env`: `cp .env.example .env`
    - Fill in all the required values (`DATABASE_URL`, `GEMINI_API_KEY`, etc.). Both services will source their configuration from this central file.

---

## 💻 Running the API Service Natively

Follow these steps to run the API & AI service directly on your machine with hot-reloading for active development.

1.  **Navigate to the service directory:**
    ```bash
    cd api_service
    ```
2.  **Create and activate a Python virtual environment:**
    ```bash
    python3 -m venv venv
    source venv/bin/activate
    ```
3.  **Install dependencies:**
    ```bash
    pip install -r requirements.txt
    ```
4.  **Run the development server:**
    ```bash
    uvicorn app.main:app --reload
    ```
The API service will be available at `http://localhost:8000`.

---

## 📦 Running the Ingestion Service Natively

Follow these steps to run the Ingestion service directly on your machine.

1.  **Navigate to the service directory:**
    ```bash
    cd ingestion_service
    ```
2.  **Install dependencies:**
    ```bash
    npm install
    ```
3.  **Run the development server:**
    ```bash
    npm run dev
    ```
The Ingestion service will be available at `http://localhost:3000`.

</br>

> #
>
> **</> Built by Mission Control | DevByZero 2025**
>
> *Defining the infinite possibilities in your DevOps pipeline.*
> ##