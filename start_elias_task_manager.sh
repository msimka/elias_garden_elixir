#!/bin/bash

# ELIAS Federation Task Manager Launcher
# Equivalent to Windows Task Manager for the entire ELIAS system

echo "🖥️  ELIAS Federation Task Manager"
echo "================================="
echo "Starting comprehensive system monitoring..."
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

# Start the task manager
mix run -e "EliasServer.TaskManagerCLI.start()" --no-halt

echo ""
echo "Task Manager session ended."