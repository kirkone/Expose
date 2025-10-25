#!/bin/bash

# Benchmark script for OneDrive sync
# Run from benchmarks/ directory: ./benchmark_onedrive.sh
# Or from root: ./benchmarks/benchmark_onedrive.sh

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT="example.site"
INPUT_DIR="$PROJECT_ROOT/projects/$PROJECT/input"

echo "🔬 OneDrive Sync Benchmark for 32-core system"
echo "=============================================="
echo ""

# Test different concurrency values
for c in 6 10 16 20 24 32; do
    echo "Testing concurrency: $c"
    echo "---"
    
    # Clean up input folder
    rm -rf "$INPUT_DIR"
    mkdir -p "$INPUT_DIR"
    
    # Run benchmark (always from project root)
    echo "Running: ./onedrive.sh -p $PROJECT -c $c"
    cd "$PROJECT_ROOT"
    /usr/bin/time -f "Time: %E (real), CPU: %P" ./onedrive.sh -p "$PROJECT" -c "$c" 2>&1 | grep -E "(Time:|successful)"
    
    echo ""
    echo "=============================================="
    echo ""
    
    # Small pause between runs
    sleep 2
done

echo "✅ Benchmark completed!"
