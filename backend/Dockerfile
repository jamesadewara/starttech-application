# ============================================
# STAGE 1: Build the Go binary
# ============================================
# We use a specific Go version on Alpine (lightweight Linux)
FROM golang:1.24-alpine AS builder

# Install git and ca-certificates (needed for fetching Go modules)
RUN apk add --no-cache git ca-certificates

# Set working directory inside the container
WORKDIR /app

# Copy only dependency files first (for caching)
COPY go.mod go.sum ./

# Download dependencies. This layer gets cached unless go.mod/go.sum change
RUN go mod download

# Copy the rest of the application source code
COPY  .

# Build the binary: static binary for Linux, no CGO
# Using BuildKit cache mounts to speed up compilation
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -v -ldflags="-w -s" -o much-to-do ./cmd/api/main.go

# ============================================
# STAGE 2: Create the runtime image with shell
# ============================================
# Use Alpine instead of distroless so we have /bin/sh to build MONGO_URI
FROM alpine:3.21

# Set working directory
WORKDIR /app

# Copy the compiled binary from the builder stage
COPY --from=builder /app/much-to-do .

# Copy swagger docs only if they exist in the builder stage
# This prevents build failure if docs were not generated
RUN if [ -d "/app/docs" ]; then cp -r /app/docs ./docs; fi

# Create non-root user (security best practice)
RUN adduser -D -u 65532 appuser
USER appuser

# Expose the port your app listens on
EXPOSE 8080

# Health check: use wget since Alpine has it (distroless didn't)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

# Build MONGO_URI from env vars, export it, then exec the binary
# This replaces the need for a separate entrypoint.sh file
ENTRYPOINT ["/app/much-to-do"]