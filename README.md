<p align="center">
  <img src="github-assets/rise-docker-ros2-container-header.png" alt="Project Header" />
</p>

---

This repository contains the standardized environment for using ROS2 within the RISE project. While the production systems don't run a Docker setup, we use the containerized approach for development purposes. 

## Building

The Docker image is available from the 'packages' menu of this repository. You can pull it from GHCR using:

```bash
docker pull ghcr.io/riserobotics/rise-os:latest
```

If you want to build it yourself locally, use the build script in the root of this repository:

```bash
./build_docker.sh
```

This script will:
- Detect your system architecture (AMD64 or ARM64)
- Set up QEMU for cross-platform emulation
- Build the image for both AMD64 and ARM64 architectures
- Verify that both builds completed successfully

Alternatively, you can build manually with:

```bash
docker build -t rise-os:latest .
```

## Running

Run the container interactively:

```bash
docker run -it --rm ghcr.io/riserobotics/rise-os:latest
```

Or if you built it locally:

```bash
docker run -it --rm rise-os:latest
```

To execute commands in a running container:

```bash
docker exec -it <container_name> /bin/zsh
```

Note: The container uses ZSH with Powerlevel10k theme by default.

## Foxglove

The image ships with `foxglove_bridge`, which exposes ROS 2 topics to [Foxglove](https://foxglove.dev) over a WebSocket on port 8765. 
Publish the port when you start the container (the rise-os-core Dev-Container already has this configured):

```bash
docker run -it --rm -p 8765:8765 ghcr.io/riserobotics/rise-os:latest
```

or

```bash
docker run -it --rm -p --net=host ghcr.io/riserobotics/rise-os:latest
```

Inside the container, start the bridge:

```bash
ros2 launch foxglove_bridge foxglove_bridge_launch.xml
```

Then open Foxglove on your machine, choose "Open connection", select "Foxglove WebSocket" and connect to `ws://localhost:8765`.