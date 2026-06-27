#!/bin/bash
# Run this script before pushing the Dockerfile to ensure multi-platform build works correctly

echo
echo "════════════════════════════════════════════════════"
echo "                 Docker Build Test                  "
echo "════════════════════════════════════════════════════"
echo


# Detect host architecture
HOST_ARCH=$(uname -m)

# Set native and cross platforms
case $HOST_ARCH in
    x86_64)
        NATIVE_PLATFORM="linux/amd64"
        CROSS_PLATFORM="linux/arm64"
        ;;
    aarch64|arm64)
        NATIVE_PLATFORM="linux/arm64"
        CROSS_PLATFORM="linux/amd64"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $HOST_ARCH"
        exit 1
        ;;
esac

echo
echo "Detected architecture: $HOST_ARCH"
echo
echo "Native platform: $NATIVE_PLATFORM"
echo "Cross-compiling for: $CROSS_PLATFORM"
echo
sleep 1

# Set up QEMU for cross-platform
echo "Setting up QEMU for cross-platform emulation..."
echo
docker run --privileged --rm tonistiigi/binfmt --install all

# Create buildx builder
if ! docker buildx inspect multiarch-builder &>/dev/null; then
    echo
    echo "Creating buildx builder..."
    echo
    docker buildx create --name multiarch-builder --use
else
    echo "Using existing buildx builder..."
    docker buildx use multiarch-builder
fi

# Bootstrap  builder
docker buildx inspect --bootstrap

echo
echo "Building Docker image for AMD64 and ARM64..."
sleep 1
echo

# Build for amd64
echo "Building for AMD64..."
docker buildx build \
    --platform linux/amd64 \
    -t rise-os:amd64 \
    . 

# Capture exit code
AMD64_EXIT_CODE=$?

# Build for arm64
echo
sleep 1
echo "Building for ARM64..."
docker buildx build \
    --platform linux/arm64 \
    -t rise-os:arm64 \
    . 

ARM64_EXIT_CODE=$?

# Display results
echo
echo "════════════════════════════════════════════════════════════════"
echo "                      Build Results                             "
echo "════════════════════════════════════════════════════════════════"
echo

if [ $AMD64_EXIT_CODE -eq 0 ]; then
    echo "AMD64: SUCCESS"
else
    echo "AMD64: FAILED (exit code $AMD64_EXIT_CODE)"
fi

if [ $ARM64_EXIT_CODE -eq 0 ]; then
    echo "ARM64: SUCCESS"
else
    echo "ARM64: FAILED (exit code $ARM64_EXIT_CODE)"
fi

echo
echo "════════════════════════════════════════════════════════════════"
