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

# Stage 2: Build the Go server
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS go_builder

ARG TARGETARCH
ARG TARGETOS

# Install build dependencies
RUN apk add --no-cache bash git

WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy the Go app source
COPY server/ ./server/

# Build the Go application with cross-compilation
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o sumika-server ./server

# Stage 3: Create the final image
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache ca-certificates libc6-compat

# Create a non-root user to run the app
RUN adduser -D appuser
USER appuser

WORKDIR /app

# Copy the compiled Go binary from the builder stage
COPY --from=go_builder /app/sumika-server /app/

# Copy the Flutter web build to the static directory
COPY --from=flutter_builder /app/client/build/web /app/web

# Copy server assets (scene images, etc.) from the Go builder stage
COPY --from=go_builder /app/server/assets /app/assets

# Expose the port the server listens on
EXPOSE 8081

# Run the server
CMD ["/app/sumika-server"]