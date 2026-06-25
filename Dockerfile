# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# % 
# % Title: Dockerfile 
# % Author: Furkan M. Lafci
# % Created: 2025-11-21
# %
# % Information: Dockerfile for building ROS2-Jazzy image for rise-os-core
# %
# % Usage: docker build -t rise-os:latest -f Dockerfile resources
# %            
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


# ====================== Base Image ======================= #

FROM ubuntu:24.04

# ================= Setting up system ===================== #


# Set ROS distribution
ARG ROS_DISTRO=jazzy

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip python3-setuptools python3-pytest\
    locales ca-certificates curl gnupg2 dirmngr lsb-release \
    software-properties-common git git-lfs nano vim wget cmake \
    libssl-dev libudev-dev pkg-config libusb-1.0-0-dev build-essential \
    libgtk-3-dev apt-transport-https libglfw3-dev libgl1-mesa-dev \
    libglu1-mesa-dev wget git at sudo

# Install user-added debian packages from 'apt_requirements' file 
COPY ./resources/apt_requirements /tmp
# Delete all comments in requirements file
RUN sed -i 's/#.*$//g' /tmp/apt_requirements
# Remove all new lines in requirements file
RUN sed -i '/^$/d' /tmp/apt_requirements
RUN apt-get update && xargs -a /tmp/apt_requirements -r apt-get install -y --no-install-recommends || true
RUN rm /tmp/apt_requirements

# Setup oh-my-bash and robbyrussell theme
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"
COPY ./resources/robbyrussell.theme.sh /root/.oh-my-bash/custom/themes/robbyrussell/robbyrussell.theme.sh
RUN sed -i 's/OSH_THEME=".*"/OSH_THEME="robbyrussell"/' /root/.bashrc

# Setup locales package
RUN locale-gen en_US en_US.UTF-8 
RUN update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8


# Install IntelRealSense drivers for camera
RUN git clone https://github.com/riserobotics/librealsense.git -b r/2.58.1 /tmp/librealsense && \
    cd /tmp/librealsense \
    ./scripts/setup_udev_rules.sh && \
    mkdir build && \
    cd build && \
    cmake ../ \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_WITH_DDS=ON && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# Install kindr for elevation_mapping
RUN apt-get update && apt-get install libpcl-dev libeigen3-dev -y --no-install-recommends
RUN git clone https://github.com/ANYbotics/kindr.git /tmp/kindr && \
    cd /tmp/kindr && \
    mkdir build && \
    cd build && \
    cmake ../ -DUSE_CMAKE=true && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# =================== Building ROS 2 ======================= #


# Enable Ubuntu Universe repo
RUN apt-get install software-properties-common -y
RUN add-apt-repository universe

# Set up keys and ROS2 repos
RUN ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -oP '"tag_name": "\K[^"]+') && \
    echo "ROS APT source version: ${ROS_APT_SOURCE_VERSION}" && \
    curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb" && \
    apt-get install -y /tmp/ros2-apt-source.deb && \
    rm -f /tmp/ros2-apt-source.deb

# Refresh apt 
RUN apt-get update
RUN apt-get upgrade -y

# Install ROS2
RUN apt-get install ros-${ROS_DISTRO}-ros-base -y

# Install ROS2 packages from "ros_requirements" file
COPY ./resources/ros_requirements /tmp
# Delete all comments in requirements file
RUN sed -i 's/#.*$//g' /tmp/ros_requirements
# Make spaces to newlines, so that there is at most one package per line
RUN sed -i 's/ /\n/g' /tmp/ros_requirements
# Remove empty lines
RUN sed -i '/^$/d' /tmp/ros_requirements
RUN cat /tmp/ros_requirements | DEBIAN_FRONTEND=noninteractive xargs -I {} apt-get  install --yes --no-install-recommends ros-${ROS_DISTRO}-{}
RUN rm /tmp/ros_requirements

# Source ROS setup script
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /root/.bashrc

# Install recommended ROS2 packages
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends  \
    python3-rosdep \
    python3-colcon-common-extensions 

# Init rosdep and update it
RUN rosdep init && rosdep update

# Installing Realsense ROS Wrapper
RUN git clone https://github.com/riserobotics/realsense-ros.git -b r/4.58.1 /tmp/realsense-ros && \
    cd /tmp/realsense-ros && \
    . /opt/ros/${ROS_DISTRO}/setup.sh && \
    rosdep install -i --from-path . --rosdistro $ROS_DISTRO --skip-keys=librealsense2 -y && \
    colcon build --install-base /opt/realsense-ros --cmake-args -DBUILD_WITH_DDS=ON


# ================ Setting Up Workspaces ==================== #

# Install user python packages from `python_requirements` file
COPY ./resources/python_requirements /tmp
# Delete all comments in requirements file
RUN sed -i 's/#.*$//g' /tmp/python_requirements
# Remove all empty lines in requirements file
RUN sed -i '/^$/d' /tmp/python_requirements
RUN pip install --no-cache-dir --break-system-packages -r /tmp/python_requirements
RUN rm /tmp/python_requirements

# Set default shell to bash
CMD [ "bash" ]

# Set working directory
WORKDIR /workspaces/rise-os-core

# Source ROS project workspace
RUN echo 'if [ -f /workspaces/rise-os-core/riseos_ws/install/setup.bash ]; then source /workspaces/rise-os-core/riseos_ws/install/setup.bash; fi' >> /root/.bashrc
# Source realsense-ros
RUN echo 'if [ -f /opt/realsense-ros/setup.bash ]; then source /opt/realsense-ros/setup.bash; fi' >> /root/.bashrc

# Copy realsense config to enable DDS with wrapper execution
COPY ./resources/.realsense-config.json /root/.realsense-config.json

# Start with startup script
COPY ./resources/startup.sh /tmp/startup.sh
RUN chmod +x /tmp/startup.sh
ENTRYPOINT ["/tmp/startup.sh"]