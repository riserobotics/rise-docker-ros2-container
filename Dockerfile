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
      software-properties-common git git-lfs nano vim wget

# Install user-added debian packages from 'apt_requirements' file 
COPY ./resources/apt_requirements /tmp
RUN xargs -a /tmp/apt_requirements -r apt-get install -y --no-install-recommends || true
RUN rm /tmp/apt_requirements

# Setup oh-my-bash and robbyrussell theme
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"
COPY ./resources/robbyrussell.theme.sh /root/.oh-my-bash/custom/themes/robbyrussell/robbyrussell.theme.sh
RUN sed -i 's/OSH_THEME=".*"/OSH_THEME="robbyrussell"/' /root/.bashrc

# Setup locales package
RUN locale-gen en_US en_US.UTF-8 
RUN update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8


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


# ================ Setting Up Workspaces ==================== #


# Install user python packages from `python_requirements` file
COPY ./resources/python_requirements /tmp
RUN pip install --no-cache-dir --break-system-packages -r /tmp/python_requirements
RUN rm /tmp/python_requirements

# Set default shell to bash
CMD [ "bash" ]

# Set working directory
WORKDIR /workspaces/rise-os-core

# Source ROS project workspace
RUN echo 'if [ -f /workspaces/rise-os-core/riseos_ws/install/setup.bash ]; then source /workspaces/rise-os-core/riseos_ws/install/setup.bash; fi' >> /root/.bashrc

# Start with startup script
COPY ./resources/startup.sh /tmp/startup.sh
RUN chmod +x /tmp/startup.sh
ENTRYPOINT ["/tmp/startup.sh"]