# 1. Base Image: Use a slim Python image for a smaller footprint
FROM python:3.8-slim

# 2. Set Environment Variables: Best practices for Python in Docker
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# 3. Set Working Directory
WORKDIR /app

# 4. Install uv for package management
RUN pip install uv

# 5. Copy dependency definition and install dependencies
# This step is separated to leverage Docker's layer caching.
# Dependencies are only re-installed when pyproject.toml changes.
COPY pyproject.toml ./
RUN uv pip install --system --no-cache -e .

# 6. Copy the rest of the application code into the container
COPY main.py .

# 7. Expose the port the app runs on
EXPOSE 8000

# 8. Define the command to run the app
# Use --host 0.0.0.0 to make it accessible from outside the container
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
