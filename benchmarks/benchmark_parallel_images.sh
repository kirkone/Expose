#!/bin/bash

# Benchmark different MAX_PARALLEL_IMAGES settings

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "======================================"
echo "Parallel Image Processing Benchmark"
echo "======================================"
echo ""
echo "Testing different parallelization levels"
echo "System: $(nproc) cores"
echo ""

# Test different parallel levels
PARALLEL_LEVELS=(4 8 12 16 20 24 30)

for level in "${PARALLEL_LEVELS[@]}"; do
    echo "======================================"
    echo "Testing MAX_PARALLEL_IMAGES=$level"
    echo "======================================"
    
    # Temporarily modify expose.sh
    cp "$PROJECT_ROOT/expose.sh" "$PROJECT_ROOT/expose.sh.backup"
    
    # Replace the MAX_PARALLEL_IMAGES calculation
    sed -i "/^MAX_PARALLEL_IMAGES=/c\MAX_PARALLEL_IMAGES=$level" "$PROJECT_ROOT/expose.sh"
    
    # Clean output
    rm -rf "$PROJECT_ROOT/output/example.site"
    
    # Run benchmark
    start=$(date +%s.%N)
    cd "$PROJECT_ROOT" && ./expose.sh -p example.site > /dev/null 2>&1
    end=$(date +%s.%N)
    
    duration=$(echo "$end - $start" | bc)
    
    echo "Time: ${duration}s"
    echo ""
    
    # Restore original
    mv "$PROJECT_ROOT/expose.sh.backup" "$PROJECT_ROOT/expose.sh"
done

echo "======================================"
echo "Summary"
echo "======================================"
echo ""
echo "Recommendation: Use the fastest stable setting"
echo ""
