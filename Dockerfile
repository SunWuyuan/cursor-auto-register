# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    default-libmysqlclient-dev \
    build-essential \
    libssl-dev \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Chrome for Playwright
RUN apt update && apt install -y wget && \
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt install -y fonts-liberation libasound2 libatk-bridge2.0-0 libatk1.0-0 \
    libatspi2.0-0 libcairo2 libcups2 libcurl3-gnutls libcurl3-nss libcurl4 libdbus-1-3 \
    libexpat1 libgbm1 libglib2.0-0 libgtk-3-0 libgtk-4-1 libnspr4 libnss3 libpango-1.0-0 \
    libvulkan1 libx11-6 libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3 \
    libxkbcommon0 libxrandr2 xdg-utils && \
    dpkg -i google-chrome-stable_current_amd64.deb && \
    apt --fix-broken install -y && \
    rm google-chrome-stable_current_amd64.deb

# Install Playwright and its dependencies
RUN pip install --no-cache-dir playwright && playwright install

# Install cryptography package for MySQL authentication
RUN pip install --no-cache-dir cryptography

# Copy requirements first for better caching
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy the entire project directory
COPY . /app/

# Make port 8000 available to the world outside this container
EXPOSE 8000

# Define environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

# Run the application
CMD python api.py --host ${API_HOST:-0.0.0.0} --port ${API_PORT:-8000} --workers ${API_WORKERS:-1} 