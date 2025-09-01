# Stage 1: Use an official, lightweight Python base image.
# Using a specific version is a production-grade best practice.
FROM python:3.11-slim

# Set environment variables for best practices
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set the working directory inside the container
WORKDIR /app

# Copy only the requirements file first to leverage Docker's build cache.
# This step is only re-run if requirements.txt changes.
COPY requirements.txt .

# Install dependencies securely and efficiently
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy the entire application source code into the container
# This includes the 'app' directory and server_runner.py.
COPY . .

# Render (and other platforms) will set the PORT environment variable.
# Your uvicorn command should listen on this port. Default to 8000 for local use.
ENV PORT 8000

# The command to run your application using uvicorn.
# We run it directly instead of via the script for clarity.
# Listens on all interfaces (0.0.0.0) which is required inside a container.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]