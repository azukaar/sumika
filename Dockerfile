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
# Add cross-compilation tools for ARM64
RUN apt-get update && apt-get install -y \
    bash \
    git \
    gcc \
    libasound2-dev \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    libc6-dev-arm64-cross \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy the Go app source
COPY server/ ./server/

# Build the Go application with cross-compilation
# Set cross-compiler for ARM64 when needed
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        export CC=aarch64-linux-gnu-gcc && \
        export CXX=aarch64-linux-gnu-g++ && \
        export AR=aarch64-linux-gnu-ar && \
        CGO_ENABLED=1 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o sumika-server ./server; \
    else \
        CGO_ENABLED=1 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o sumika-server ./server; \
    fi

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
    && ln -s /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# Create Python virtual environment and install packages
# RUN python3 -m venv /opt/venv
# ENV PATH="/opt/venv/bin:$PATH"

# Install Python packages for voice processing
RUN pip install --break-system-packages --no-cache-dir \
    "numpy<2" \
    faster-whisper \
    pyaudio \
    soundfile \
    openwakeword \
    librosa \
    pydub

# Optional: Install PyTorch with CUDA support (uncomment if needed)
# RUN pip install --no-cache-dir \
#     torch \
#     torchaudio \
#     --index-url https://download.pytorch.org/whl/cu121

# Create a non-root user to run the app
RUN useradd -m -u 1000 appuser
RUN usermod -a -G audio appuser

RUN chown -R appuser /usr/local/lib/python3.11/dist-packages/openwakeword/

# Run /app/assets/voice/preload.py
RUN python /app/assets/voice/preload.py

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