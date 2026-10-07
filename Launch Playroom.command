#!/bin/bash
TASK_DIR="$(cd "$(dirname "$0")" && pwd)"
open -n "$TASK_DIR/.prototype-build/Build/Products/Debug/Fonsters.app" --args --prototype
