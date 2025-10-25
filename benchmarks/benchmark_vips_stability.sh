#!/bin/bash

# VIPS Stability Benchmark
# Tests VIPS processing under various stress conditions to detect segfaults

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_IMAGE="$PROJECT_ROOT/projects/example.site/input/01 Events/Racing/027320.jpg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "VIPS Stability Benchmark"
echo "======================================"
echo ""
echo "Test image: $(basename "$TEST_IMAGE")"
echo "Image size: $(du -h "$TEST_IMAGE" | cut -f1)"
echo "Dimensions: $(vipsheader -f width "$TEST_IMAGE")x$(vipsheader -f height "$TEST_IMAGE")"
echo ""

# Ensure VIPS_CONCURRENCY is set
export VIPS_CONCURRENCY=1
echo "VIPS_CONCURRENCY: $VIPS_CONCURRENCY"
echo ""

# Test 1: Sequential processing with all resolutions
echo "======================================"
echo "Test 1: Sequential - 10 runs × 10 resolutions"
echo "======================================"
source_width=$(vipsheader -f width "$TEST_IMAGE")
resolutions="400 640 800 1024 1280 1920 2048 2560 3440 5120"
success=0
failed=0

for test in {1..10}; do
    echo -n "Run $test: "
    
    vips copy "$TEST_IMAGE" /tmp/seq_$test.v 2>/dev/null || { 
        echo -e "${RED}COPY FAILED${NC}"
        ((failed++))
        continue
    }
    
    for res in $resolutions; do
        scale=$(echo "$res / $source_width" | bc -l)
        
        if ! vips resize /tmp/seq_$test.v /tmp/seq_${test}_${res}.v $scale 2>/dev/null; then
            echo -e -n "${RED}X${NC}"
            ((failed++))
            rm -f /tmp/seq_$test.v /tmp/seq_${test}_*.v
            break
        fi
        
        if ! vips jpegsave /tmp/seq_${test}_${res}.v /tmp/seq_${test}_${res}.jpg --Q 90 2>/dev/null; then
            echo -e -n "${RED}X${NC}"
            ((failed++))
            rm -f /tmp/seq_$test.v /tmp/seq_${test}_*.v /tmp/seq_${test}_*.jpg
            break
        fi
        
        echo -n "."
        ((success++))
        rm -f /tmp/seq_${test}_${res}.v /tmp/seq_${test}_${res}.jpg
    done
    
    rm -f /tmp/seq_$test.v
    echo -e " ${GREEN}✔${NC}"
done

echo ""
echo -e "Results: ${GREEN}$success SUCCESS${NC}, ${RED}$failed FAILED${NC}"
echo ""

# Test 2: Parallel processing - different images
echo "======================================"
echo "Test 2: Parallel - 12 processes × 10 resolutions"
echo "         (simulating real workflow)"
echo "======================================"

# Get all JPG files from the project
mapfile -t test_images < <(find "$PROJECT_ROOT/projects/example.site/input" -name "*.jpg" | head -12)
num_images=${#test_images[@]}

if [ $num_images -lt 12 ]; then
    echo -e "${YELLOW}Warning: Only $num_images images found, expected 12${NC}"
fi

echo "Processing $num_images images in parallel..."
echo ""

start_time=$(date +%s.%N)
success_count=0
failed_count=0

for idx in "${!test_images[@]}"; do
    (
        img="${test_images[$idx]}"
        img_width=$(vipsheader -f width "$img" 2>/dev/null)
        
        vips copy "$img" /tmp/real_${idx}.v 2>/dev/null || { echo -n "X"; exit 1; }
        
        for res in 400 640 800 1024 1280 1920 2048 2560 3440 5120; do
            scale=$(echo "$res / $img_width" | bc -l)
            vips resize /tmp/real_${idx}.v /tmp/real_${idx}_${res}.v $scale 2>/dev/null || { echo -n "X"; exit 1; }
            vips jpegsave /tmp/real_${idx}_${res}.v /tmp/real_${idx}_${res}.jpg --Q 90 --optimize-coding --strip 2>/dev/null || { echo -n "X"; exit 1; }
            rm -f /tmp/real_${idx}_${res}.v /tmp/real_${idx}_${res}.jpg
        done
        
        rm -f /tmp/real_${idx}.v
        echo -n "."
    ) &
done

wait

end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)

echo ""
echo ""
echo -e "Duration: ${GREEN}${duration}s${NC}"
echo ""

# Test 3: Stress test - same image processed by multiple processes
echo "======================================"
echo "Test 3: Stress - 20 processes on SAME image"
echo "         (worst case scenario)"
echo "======================================"

stress_success=0
stress_failed=0

start_time=$(date +%s.%N)

for test in {1..20}; do
    (
        source_width=$(vipsheader -f width "$TEST_IMAGE" 2>/dev/null)
        vips copy "$TEST_IMAGE" /tmp/stress_${test}.v 2>/dev/null || { echo -n "X"; exit 1; }
        
        for res in 400 640 800 1024 1280 1920 2048 2560 3440 5120; do
            scale=$(echo "$res / $source_width" | bc -l)
            vips resize /tmp/stress_${test}.v /tmp/stress_${test}_${res}.v $scale 2>/dev/null || { echo -n "X"; rm -f /tmp/stress_${test}.v /tmp/stress_${test}_*.v /tmp/stress_${test}_*.jpg; exit 1; }
            vips jpegsave /tmp/stress_${test}_${res}.v /tmp/stress_${test}_${res}.jpg --Q 90 --optimize-coding --strip 2>/dev/null || { echo -n "X"; rm -f /tmp/stress_${test}.v /tmp/stress_${test}_*.v /tmp/stress_${test}_*.jpg; exit 1; }
            rm -f /tmp/stress_${test}_${res}.v /tmp/stress_${test}_${res}.jpg
        done
        
        rm -f /tmp/stress_${test}.v
        echo -n "."
    ) &
done

wait

end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)

echo ""
echo ""
echo -e "Duration: ${GREEN}${duration}s${NC}"
echo ""

# Summary
echo "======================================"
echo "Summary"
echo "======================================"
echo ""
echo "✓ Test 1: Sequential processing - stable baseline"
echo "✓ Test 2: Parallel different images - real workflow"
echo "✓ Test 3: Parallel same image - stress test"
echo ""
echo "If all tests show only dots (.) and no X marks,"
echo "VIPS is stable with current settings."
echo ""
echo "Current settings:"
echo "  - VIPS_CONCURRENCY=1"
echo "  - /tmp for temp files"
echo "  - Retry logic in expose.sh"
echo ""
