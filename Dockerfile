ARG PYTHON_IMAGE_VERSION=3.12-slim

# Build stage
FROM python:${PYTHON_IMAGE_VERSION} AS builder

# Pre-configure Poetry
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    POETRY_VERSION=1.8.3 \
    POETRY_HOME="/opt/poetry" \
    POETRY_NO_INTERACTION=1

ENV PATH="$POETRY_HOME/bin:$PATH"

# Install build dependencies and Poetry
RUN apt-get update && apt-get install -y python3-dev libpq-dev gcc curl \
    && curl -sSL https://install.python-poetry.org | python3 -

WORKDIR /app

# Install application dependencies using Poetry
COPY poetry.toml pyproject.toml poetry.lock ./
RUN poetry install --only main --no-root

# Runtime stage
FROM python:${PYTHON_IMAGE_VERSION}

RUN apt-get update && apt-get install -y libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the virtual environment
COPY --from=builder /app/.venv /app/.venv

# Setup environment
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH"

COPY healthcheck.py ./

# Create a non-root user and group
RUN groupadd --gid 10001 mlflow && \
    useradd --uid 10001 -g mlflow -M -d /nonexistent mlflow && \ 
    chown -R mlflow:mlflow /app

# Switch to non-root user
USER mlflow

EXPOSE 5000
CMD ["sh", "-c", "mlflow server --host 0.0.0.0 --app-name basic-auth --port 5000 --backend-store-uri $BACKEND_STORE_URI"]