# Real-time CTR Calculation Pipeline

This project demonstrates a complete, real-time data pipeline for calculating Click-Through-Rate (CTR) from streaming impression and click events. The pipeline is built using Kafka, Flink, and Redis, and includes a FastAPI backend to serve the results.

## 🏛️ Architecture

The data flows through the system as follows:

```
                                      ┌──────────────────┐
                                      │   Serving API    │
                                      │    (FastAPI)     │
                                      └──────────────────┘
                                               ▲
                                               │ (GET /ctr/...)
                                               │
┌──────────┐   ┌───────┐   ┌───────────┐   ┌───────┐
│ Producers│──>│ Kafka │──>│ Flink App │──>│ Redis │
└──────────┘   └───────┘   └───────────┘   └───────┘
     (Python)   (Events)    (10s Window)   (Hashes) │
                                                    │
                                                    ▼
                                             ┌──────────────┐
                                             │ RedisInsight │
                                             └──────────────┘
```

## ✨ Key Features

-   **Real-time Processing:** Calculates CTR over a **10-second** tumbling window.
-   **Stateful Analysis:** Maintains both the **latest** and the **immediately preceding** CTR results for comparative analysis.
-   **RESTful API:** A FastAPI server provides endpoints to access the calculated CTR data.
-   **Containerized:** The entire environment is containerized using Docker and managed with Docker Compose and shell scripts.
-   **Scalable:** Built on industry-standard, scalable components like Kafka and Flink.

## 🧩 Components

| Component         | Directory         | Description                                                                                                                            |
| ----------------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| **Data Producers**  | `producers/`      | Python scripts that simulate user impressions and clicks, sending them as events to Kafka topics.                                    |
| **Event Stream**    | `docker-compose`  | A 3-broker Kafka cluster for ingesting event streams.                                                                                  |
| **Flink Processor** | `flink-app/`      | A Java/Flink application that consumes events, performs a stateful CTR calculation, and sinks results to Redis.                      |
| **Data Store**      | `docker-compose`  | A Redis instance used to store the latest and previous CTR calculation results in Hashes.                                            |
| **Serving API**     | `serving-api/`    | A Python/FastAPI application that reads from Redis and exposes CTR data via a REST API. Managed by Docker Compose.                   |
| **Monitoring UIs**  | `docker-compose`  | Kafka UI, Flink Dashboard, and RedisInsight for observing and managing the system components.                                          |

## 🛠️ Technology Stack

-   **Streaming:** Apache Kafka, Apache Flink
-   **Backend & Serving:** FastAPI, Uvicorn
-   **Database:** Redis
-   **Languages:** Java 11, Python 3.8
-   **Containerization:** Docker, Docker Compose
-   **Build Tools:** Maven, uv

## 🚀 Getting Started

Follow these steps to get the entire pipeline running on your local machine.

### Prerequisites

-   Docker & Docker Compose
-   An internet connection for pulling Docker images.

### Step 1: Start Infrastructure Services

This command starts Kafka, Zookeeper, Flink (JobManager & TaskManager), and Redis.

```bash
docker-compose up -d
```

### Step 2: Deploy the Flink Job

This script compiles the Java application (if needed) and submits it to the Flink cluster.

```bash
./scripts/deploy-flink-job.sh
```

### Step 3: Start the Data Producers

This script starts the Python scripts that generate and send impression/click data to Kafka.

```bash
./scripts/start-producers.sh
```

The entire pipeline is now running!

## 📊 How to Verify

You can observe the system and access the data in several ways.

### Monitoring Dashboards

| Service        | URL                               | Description                               |
| -------------- | --------------------------------- | ----------------------------------------- |
| **Serving API**  | `http://localhost:8000/docs`      | Interactive API documentation (Swagger UI). |
| **Flink UI**     | `http://localhost:8081`           | Monitor Flink jobs and cluster status.    |
| **Kafka UI**     | `http://localhost:8080`           | Browse Kafka topics and messages.         |
| **RedisInsight** | `http://localhost:5540`           | GUI for inspecting data stored in Redis.  |

### API Endpoints

The Serving API provides the following main endpoints:

| Method | Endpoint                  | Description                                          |
| ------ | ------------------------- | ---------------------------------------------------- |
| `GET`  | `/ctr/latest`             | Get the latest CTR data for all products.            |
| `GET`  | `/ctr/previous`           | Get the previous CTR data for all products.          |
| `GET`  | `/ctr/{product_id}`       | Get a combined view of latest & previous CTR for one product. |

### Direct Redis Check

You can also connect directly to Redis to see the data hashes.

```bash
# Connect to the Redis container
docker exec -it redis redis-cli

# Check the latest and previous keys
HGETALL ctr:latest
HGETALL ctr:previous
```

## 🛑 How to Stop

Use the provided scripts to stop the different parts of the application.

```bash
# Stop the Serving API container
docker-compose stop serving-api

# Stop the data producers
./scripts/stop-producers.sh

# Stop the Flink job
./scripts/stop-flink-job.sh

# Stop and remove all infrastructure services
docker-compose down
```

## 📜 Scripts Overview

This project includes several helper scripts in the `/scripts` directory to simplify management:

| Script                 | Description                                                              |
| ---------------------- | ------------------------------------------------------------------------ |
| `create-topics.sh`     | Creates the required `impressions` and `clicks` topics in Kafka.         |
| `deploy-flink-job.sh`  | Deploys the Flink application to the cluster.                            |
| `start-producers.sh`   | Starts the Python data producers in the background.                      |
| `stop-producers.sh`    | Stops the background producer processes.                                 |
| `stop-flink-job.sh`    | Finds and cancels the running Flink job.                                 |

*Note: You may need to make scripts executable first: `chmod +x scripts/*.sh`*

## ⚙️ Configuration Details

### Flink Processing Logic

-   **Window:** 10-second Tumbling Window
-   **Time Characteristic:** Event Time
-   **Watermark:** 3 seconds (handles events arriving up to 3s late)
-   **Allowed Lateness:** 5 seconds (allows window to be updated by very late events)

### Redis Data Structure

-   **`ctr:latest`**: A Redis Hash storing the most recent CTR results for each product.
    -   `field`: `product_id`
    -   `value`: JSON string with CTR data
-   **`ctr:previous`**: A Redis Hash storing the results from the window immediately preceding the latest one. Structure is identical to `ctr:latest`.

---

*This project was iteratively developed and improved by a user in collaboration with the AI assistants **Claude** and **Gemini**.*
