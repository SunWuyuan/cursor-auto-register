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
    && rm -rf /var/lib/apt/lists/*

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

# Copy requirements first for better caching
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy the current directory contents into the container at /app
COPY . /app

# 添加等待脚本
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.9.0/wait /wait
RUN chmod +x /wait

# Make port 8000 available to the world outside this container
EXPOSE 8000

# Define environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

# Run the application - 修改启动命令，确保在正确的目录中运行
CMD /wait && cd /app && python -m uvicorn api:app --host ${API_HOST} --port ${API_PORT} --workers ${API_WORKERS} 