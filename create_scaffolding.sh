#!/bin/bash

# Check if directory path is provided
if [ -z "$1" ]; then
    echo "Usage: ./create_project.sh <directory_path>"
    exit 1
fi

# Create the directory if it doesn't exist
mkdir -p $1

# Navigate to the directory
cd $1

# Download package.json using wget from a fixed URL
wget -O package.json <fixed_URL_placeholder>

# Create src and test folders
mkdir src test

# Write "modulekit/=../." into remappings.txt
echo "modulekit/=../." > remappings.txt

echo "Project scaffolding created successfully."
