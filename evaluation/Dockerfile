FROM python:3.12-slim

# Set default working directory.
WORKDIR /usr/local/bin

# Copy over Python dependencies file and install.
COPY requirements.txt .
RUN pip install \
    --no-cache-dir \
    --break-system-packages \
    -r requirements.txt

# Copy over validation and scoring scripts.
COPY validate.py .
COPY score.py .