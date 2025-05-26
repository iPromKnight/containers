#!/bin/bash

echo -e "\nBootstrap:\nworld_file_name=$WORLD_FILENAME\nconfigpath=$CONFIGPATH\nlogpath=$LOGPATH\n"

if [ -z "$(ls -A /tshock/ServerPlugins)" ]; then
  echo "Copying plugins..."
  cp /plugins/* /tshock/ServerPlugins
fi

WORLD_PATH="$CONFIGPATH/$WORLD_FILENAME"

autocreate_flag=false
for arg in "$@"; do
  if [ "$arg" = "-autocreate" ]; then
    autocreate_flag=true
    break
  fi
done

if [ -z "$WORLD_FILENAME" ]; then
  echo "No world file specified in environment WORLD_FILENAME."
  if [ -z "$@" ]; then
    echo "Running server setup..."
  else
    echo "Running server with command flags: $@"
  fi
  exec tshock -configpath "$CONFIGPATH" -logpath "$LOGPATH" "$@"
else
  echo "Environment WORLD_FILENAME specified"
  if [ -f "$WORLD_PATH" ] || [ "$autocreate_flag" = true ]; then
    echo "Loading to world $WORLD_FILENAME..."
    exec tshock -configpath "$CONFIGPATH" -logpath "$LOGPATH" -world "$WORLD_PATH" "$@"
  else
    echo "Unable to locate $WORLD_PATH and -autocreate flag is not set."
    echo "Please make sure your world file is volumed into docker: -v <path_to_world_file>:/root/.local/share/Terraria/Worlds"
    echo "Alternatively, use the -autocreate flag to create a new world."
    exit 1
  fi
fi