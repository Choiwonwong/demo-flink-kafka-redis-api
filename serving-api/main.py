import json
import os

from fastapi import FastAPI, HTTPException
from redis import Redis

app = FastAPI(
    title="CTR Serving API",
    description="An API to serve real-time and previous Click-Through-Rate data.",
    version="1.1.0"
)

# --- Redis Connection ---
redis_client = None
try:
    redis_host = os.environ.get("REDIS_HOST", "localhost")
    redis_client = Redis(host=redis_host, port=6379, db=0, decode_responses=True)
    redis_client.ping()
    print(f"Successfully connected to Redis at {redis_host}.")
except Exception as e:
    print(f"Could not connect to Redis: {e}")
    redis_client = None


# --- API Endpoints ---

@app.get("/")
def read_root():
    """A welcome message and API status."""
    return {
        "message": "Welcome to the CTR Serving API",
        "redis_status": "connected" if redis_client else "disconnected"
    }


@app.get("/ctr/latest", summary="Get Latest CTR for All Products")
def get_all_latest_ctr():
    """
    Retrieves the latest CTR data for all products from the 'ctr:latest' Redis hash.
    """
    if not redis_client:
        raise HTTPException(status_code=503, detail="Redis service is unavailable.")

    try:
        ctr_hash = redis_client.hgetall("ctr:latest")
        if not ctr_hash:
            return {}
        result = {key: json.loads(value) for key, value in ctr_hash.items()}
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An error occurred: {str(e)}")


@app.get("/ctr/previous", summary="Get Previous CTR for All Products")
def get_all_previous_ctr():
    """
    Retrieves the previous CTR data for all products from the 'ctr:previous' Redis hash.
    """
    if not redis_client:
        raise HTTPException(status_code=503, detail="Redis service is unavailable.")

    try:
        ctr_hash = redis_client.hgetall("ctr:previous")
        if not ctr_hash:
            return {}
        result = {key: json.loads(value) for key, value in ctr_hash.items()}
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An error occurred: {str(e)}")


@app.get("/ctr/{product_id}", summary="Get Latest and Previous CTR for a Product")
def get_ctr_by_product_id(product_id: str):
    """
    Retrieves both the latest and previous CTR data for a specific **product_id**.
    """
    if not redis_client:
        raise HTTPException(status_code=503, detail="Redis service is unavailable.")

    try:
        latest_json = redis_client.hget("ctr:latest", product_id)
        previous_json = redis_client.hget("ctr:previous", product_id)

        if not latest_json and not previous_json:
            raise HTTPException(
                status_code=404,
                detail=f"No CTR data found for product_id '{product_id}'."
            )

        return {
            "latest": json.loads(latest_json) if latest_json else None,
            "previous": json.loads(previous_json) if previous_json else None
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An error occurred: {str(e)}")


# To run this app locally:
# 1. cd serving-api
# 2. uv venv && source .venv/bin/activate
# 3. uv pip install -e .
# 4. uvicorn main:app --host 0.0.0.0 --port 8000 --reload