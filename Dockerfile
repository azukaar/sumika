# Multi-stage build for efficiency

# Stage 1: Build the Flutter web app
FROM --platform=$BUILDPLATFORM dart:stable AS flutter_builder

# Install Flutter
RUN apt-get update && apt-get install -y curl git unzip xz-utils zip libglu1-mesa

# Get Stable Branch
RUN git clone https://github.com/flutter/flutter.git /flutter && \
  git -C /flutter checkout stable
ENV PATH="/flutter/bin:${PATH}"

# Copy the Flutter app source
WORKDIR /app
COPY client/ ./client/
WORKDIR /app/client

# Build the Flutter web app
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Build the Go server - Using Debian instead of Alpine for CGO compatibility
FROM --platform=$BUILDPLATFORM golang:1.23 AS go_builder

ARG TARGETARCH
ARG TARGETOS

# Install build dependencies including audio libraries for malgo
RUN apt-get update && apt-get install -y \
    bash \
    git \
    gcc \
    libasound2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy the Go app source
COPY server/ ./server/

# Build the Go application with cross-compilation
# CGO_ENABLED=1 for audio libraries like malgo
RUN CGO_ENABLED=1 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o sumika-server ./server

# Stage 3: Create the final image using Debian instead of Alpine
FROM debian:bookworm-slim

# Install runtime dependencies including Python and audio libraries
RUN apt-get update && apt-get install -y \
    ca-certificates \
    nodejs \
    npm \
    python3 \
    python3-pip \
    python3-venv \
    libasound2 \
    portaudio19-dev \
    ffmpeg \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create Python virtual environment and install packages
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python packages for voice processing
RUN pip install --no-cache-dir \
    numpy \
    faster-whisper \
    pyaudio \
    soundfile \
    pydub

# Optional: Install PyTorch with CUDA support (uncomment if needed)
# RUN pip install --no-cache-dir \
#     torch \
#     torchaudio \
#     --index-url https://download.pytorch.org/whl/cu121

# Create a non-root user to run the app
RUN useradd -m -u 1000 appuser
USER appuser

WORKDIR /app

# Copy the compiled Go binary from the builder stage
COPY --from=go_builder /app/sumika-server /app/

# Copy the Flutter web build to the static directory
COPY --from=flutter_builder /app/client/build/web /app/web

# Copy server assets (scene images, voice assets, etc.) from the Go builder stage
COPY --from=go_builder /app/server/assets /app/assets

# Copy device metadata script and install dependencies
COPY device-metadata-script/ /app/device-metadata-script/
USER root
WORKDIR /app/device-metadata-script
RUN npm install --production
WORKDIR /app
USER appuser

# Expose the port the server listens on
EXPOSE 8081

# Run the server
CMD ["/app/sumika-server"]