#!/bin/bash

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# % 
# % Title: startup_script.sh 
# % Author: Furkan M. Lafci
# % Created: 2025-11-21
# %
# % Information: Start script for ROS2 container

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Get absolute path of project folder in container (project must have "rise-os-core" in it's name)
PROJECT_PATH=$(mount | grep rise-os-core | awk '{print $3}')


# ------ Enable git support in container ------


if [ -f /root/.ssh/config ]; then
  echo -e "\n\n############ Change owner of .ssh folder ##############\n"

  chmod 600 /root/.ssh/config
  chown root:root /root/.ssh/config

  echo -e "######################## Done! ########################\n\n"
fi


echo -e "############# Marking Git repos as safe ###############\n\n"
# Find every .git folder, fix ownership, and mark parent folder as safe for git commands
find $PROJECT_PATH \( -type d -name ".git" -o -type f -name ".git" \) | while read -r gitdir; do
  repo_dir=$(dirname "$gitdir")
  echo $repo_dir
  git config --global --add safe.directory "$repo_dir"
done
echo -e "\n\n######################## Done! ########################\n\n"


# ---------- Make files executable ----------


echo -e "\n############## Making scripts executable ##############\n\n"

# Disable git tracking for file mode (so it doesn't get marked as changed when using chmod)
cd $PROJECT_PATH
git config --global --add safe.directory .
git config core.fileMode false

# Move to source folder
cd $PROJECT_PATH/riseos_ws/src

# Make top level shell scripts executable via chmod (e.g setup_env.sh)
echo "Scripts made executable with chmod:"
echo -e "________________________________________________________\n"
find . -maxdepth 7 -type d -name "venv" -prune -o -type f \( -name "*.sh" -o -name "*.py" -o -name "*.launch" \) -print -exec chmod +x {} \; -exec echo "  Adjusted: {}" \;


echo -e "\n\n######################## Done! ########################\n\n"

# Move to project path
cd $PROJECT_PATH

# Start bash shell and clear the terminal
exec bash -c "clear; exec bash"