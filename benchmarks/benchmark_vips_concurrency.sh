#!/bin/bash

# VIPS Concurrency Benchmark
# Tests different VIPS_CONCURRENCY settings for speed and stability

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "======================================"
echo "VIPS Concurrency Benchmark"
echo "======================================"
echo ""
echo "Testing different VIPS_CONCURRENCY values"
echo "with parallel image processing."
echo ""

# Test configurations
CONCURRENCY_VALUES=(1 2 4 8 0)  # 0 = default (no limit)
RUNS_PER_TEST=3

# Store results
declare -A results_time
declare -A results_stability

for concurrency in "${CONCURRENCY_VALUES[@]}"; do
    if [ "$concurrency" -eq 0 ]; then
        label="default"
        export VIPS_CONCURRENCY=
        unset VIPS_CONCURRENCY
    else
        label="$concurrency"
        export VIPS_CONCURRENCY=$concurrency
    fi
    
    echo "======================================"
    echo -e "Testing VIPS_CONCURRENCY=${BLUE}${label}${NC}"
    echo "======================================"
    echo ""
    
    total_time=0
    total_errors=0
    
    for run in $(seq 1 $RUNS_PER_TEST); do
        echo -n "  Run $run/$RUNS_PER_TEST: "
        
        # Clean output directory
        rm -rf "$PROJECT_ROOT/output/example.site"
        
        # Run expose.sh and capture time
        start=$(date +%s.%N)
        
        if cd "$PROJECT_ROOT" && ./expose.sh -p example.site > /tmp/expose_output_${concurrency}_${run}.log 2>&1; then
            end=$(date +%s.%N)
            duration=$(echo "$end - $start" | bc)
            total_time=$(echo "$total_time + $duration" | bc)
            
            # Check for segfaults in output
            if grep -q "Segmentation fault" /tmp/expose_output_${concurrency}_${run}.log; then
                echo -e "${RED}${duration}s (SEGFAULT!)${NC}"
                ((total_errors++))
            else
                echo -e "${GREEN}${duration}s${NC}"
            fi
        else
            end=$(date +%s.%N)
            duration=$(echo "$end - $start" | bc)
            echo -e "${RED}${duration}s (FAILED!)${NC}"
            ((total_errors++))
        fi
        
        rm -f /tmp/expose_output_${concurrency}_${run}.log
    done
    
    avg_time=$(echo "scale=3; $total_time / $RUNS_PER_TEST" | bc)
    results_time[$label]=$avg_time
    results_stability[$label]=$total_errors
    
    echo ""
    echo -e "  Average: ${BLUE}${avg_time}s${NC}"
    echo -e "  Errors: ${RED}${total_errors}/${RUNS_PER_TEST}${NC}"
    echo ""
done

# Summary
echo "======================================"
echo "Summary"
echo "======================================"
echo ""
printf "%-15s %-15s %-15s\n" "CONCURRENCY" "AVG TIME" "ERRORS"
echo "----------------------------------------------"

fastest_time=""
fastest_label=""

for concurrency in "${CONCURRENCY_VALUES[@]}"; do
    if [ "$concurrency" -eq 0 ]; then
        label="default"
    else
        label="$concurrency"
    fi
    
    avg_time="${results_time[$label]}"
    errors="${results_stability[$label]}"
    
    # Find fastest
    if [ -z "$fastest_time" ] || [ $(echo "$avg_time < $fastest_time" | bc) -eq 1 ]; then
        if [ "$errors" -eq 0 ]; then
            fastest_time=$avg_time
            fastest_label=$label
        fi
    fi
    
    # Color code based on errors
    if [ "$errors" -eq 0 ]; then
        color=$GREEN
    else
        color=$RED
    fi
    
    printf "${color}%-15s %-15s %-15s${NC}\n" "$label" "${avg_time}s" "$errors"
done

echo ""
echo -e "${GREEN}✓ Fastest stable configuration: VIPS_CONCURRENCY=${fastest_label} (${fastest_time}s)${NC}"
echo ""

# Calculate speedup
if [ "$fastest_label" != "1" ]; then
    speedup=$(echo "scale=1; (${results_time[1]} - $fastest_time) / ${results_time[1]} * 100" | bc)
    if [ $(echo "$speedup > 0" | bc) -eq 1 ]; then
        echo -e "${YELLOW}⚡ Switching from VIPS_CONCURRENCY=1 to ${fastest_label} would be ${speedup}% faster${NC}"
    else
        speedup_neg=$(echo "scale=1; ($fastest_time - ${results_time[1]}) / $fastest_time * 100" | bc)
        echo -e "${YELLOW}⚠ VIPS_CONCURRENCY=1 is ${speedup_neg}% faster than ${fastest_label}${NC}"
    fi
fi

echo ""
