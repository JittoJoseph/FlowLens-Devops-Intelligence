#!/bin/bash
# clean_pycache.sh
# Recursively removes all __pycache__ directories from current directory

echo "Cleaning all __pycache__ directories under $(pwd)..."

# Find and remove __pycache__ directories
find . -type d -name "__pycache__" -exec rm -rf {} +

echo "Cleanup complete."
