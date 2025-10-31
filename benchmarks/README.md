# Benchmarks

This directory contains performance benchmark scripts for the Expose static site generator.

## Available Benchmarks

### OneDrive Sync Benchmark

**File:** `benchmark_onedrive.sh`

Tests the OneDrive sync script with different concurrency levels to find the optimal setting for your system.

**Usage:**
```bash
# From project root
./benchmarks/benchmark_onedrive.sh

# Or from benchmarks directory
cd benchmarks
./benchmark_onedrive.sh
```

**What it tests:**
- Concurrency levels: 6, 10, 16, 20, 24, 32
- Measures real time and CPU usage
- Cleans input folder between runs for accurate results
- Tests with the `example.site` project

**Sample output:**
```
🔬 OneDrive Sync Benchmark for 32-core system
==============================================

Testing concurrency: 6
---
Running: ./onedrive.sh -p example.site -c 6
✅ Download completed: 24 successful, 0 failed
Time: 1:05.16 (real), CPU: 11%

Testing concurrency: 24
---
Running: ./onedrive.sh -p example.site -c 24
✅ Download completed: 24 successful, 0 failed
Time: 0:53.70 (real), CPU: 14%
```

**Results for 32-core system (24 images):**
- c=6: 1:05.16 (baseline)
- c=24: 0:53.70 (**17.6% faster** ✅)

---

### VIPS Concurrency Benchmark

**File:** `benchmark_vips_concurrency.sh`

Tests different VIPS_CONCURRENCY settings to find the optimal balance between speed and stability.

**Usage:**
```bash
./benchmarks/benchmark_vips_concurrency.sh
```

**What it tests:**
- VIPS_CONCURRENCY values: 1, 2, 4, 8, default (unlimited)
- Runs each configuration 3 times for accuracy
- Detects segfaults and errors
- Tests with full `expose.sh` workflow

**Results for 32-core system (24 images × 10 resolutions):**
- VIPS_CONCURRENCY=1: 5.636s (100% stable) ✅ **RECOMMENDED**
- VIPS_CONCURRENCY=2: 5.553s (100% stable, 1.5% faster)
- VIPS_CONCURRENCY=default: 5.725s (**segfaults detected!** ❌)

---

### VIPS Stability Benchmark

**File:** `benchmark_vips_stability.sh`

Stress-tests VIPS under various conditions to verify stability.

**Usage:**
```bash
./benchmarks/benchmark_vips_stability.sh
```

**What it tests:**
1. **Sequential test**: 10 runs × 10 resolutions (baseline stability)
2. **Parallel test**: 12 different images × 10 resolutions (real workflow)
3. **Stress test**: 20 processes on same image × 10 resolutions (worst case)

**Sample output:**
```
======================================
VIPS Stability Benchmark
======================================

Test 1: Sequential - 10 runs × 10 resolutions
Run 1: .......... ✔
Run 10: .......... ✔
Results: 100 SUCCESS, 0 FAILED

Test 2: Parallel - 12 processes × 10 resolutions
............
Duration: 3.187s

Test 3: Stress - 20 processes on SAME image
....................
Duration: 2.765s
```

**Success criteria:** All dots (.), no X marks = stable configuration

## Creating New Benchmarks

When adding new benchmarks:

1. Use absolute paths or properly resolve relative paths
2. Clean up state between test runs
3. Measure both time and resource usage
4. Test multiple configurations
5. Document results in this README

## Requirements

- `time` command (usually pre-installed)
- Project must be configured (e.g., `projects/example.site/project.config`)
- Internet connection (for OneDrive benchmarks)

## Notes

- Benchmarks may take several minutes to complete
- Results vary based on network speed, disk I/O, and system load
- Run benchmarks when system is idle for best accuracy
- OneDrive benchmark requires valid SHARE_URL in project.config
