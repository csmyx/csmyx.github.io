#!/bin/bash

# Check if two arguments are provided
if [ $# -ne 2 ]; then
    echo "usage: ./hugo.sh series_name post_name."
    exit 1
fi

series=$1
post_name=$2
file_path="content/posts/$series/$post_name"

# 检查文件是否已存在
if [ -f "$file_path" ]; then
    read -p "File $file_path already exists. Overwrite it? (y/n, default n): " overwrite_choice
    overwrite_choice=${overwrite_choice:-n}
    if [ "$overwrite_choice" != "y" ]; then
        echo "User canceled, exit."
        exit 0
    fi
    rm "$file_path"
fi

# `series` will be set to the meta head atomatically by archetypes/default.md template
hugo new "posts/$series/$post_name"


# # Check the execution result of the hugo command
# if [ $? -ne 0 ]; then
#     echo "Error occurred while executing the hugo new command."
#     exit 1
# fi
    