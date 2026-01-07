#!/bin/bash
#
# zkCNN MLP (Multi-Layer Perceptron) Demo Script
#
# Usage: ./demo_mlp.sh [input_output_size] [num_layers] [max_threads]
#
# Parameters:
#   input_output_size - Size of input/output vectors (n in n×n layers) (default: 1024)
#   num_layers        - Number of fully connected layers (default: 16)
#   max_threads       - Maximum number of parallel threads (default: auto-detect CPU cores)
#
# Network Structure:
#   Each layer: X_{i+1} = σ(W_i X_i + b_i)
#   Where W_i is input_output_size×input_output_size, b_i is input_output_size×1
#
# Examples:
#   ./demo_mlp.sh              # Use defaults (1024×1024 layers, 16 layers, auto CPU cores)
#   ./demo_mlp.sh 128 4        # 128×128 layers, 4 layers, auto CPU cores
#   ./demo_mlp.sh 32 16 8      # 32×32 layers, 16 layers, max 8 threads
#

set -x

# ==================================================
# Memory Monitoring Setup
# ==================================================
MEMORY_LOG_FILE="/tmp/zkcnn_memory_$$.log"
ZKCNN_PID=""
MAX_VM_PEAK_KB=0
MAX_VM_HWM_KB=0

# Function to monitor memory usage (monitor the actual zkCNN process)
monitor_memory() {
    local pid=$1
    local log_file=$2

    # Redirect all output to /dev/null to ensure complete silence
    {
        while true; do
            if [ -f "/proc/$pid/status" ] && kill -0 $pid 2>/dev/null; then
                # Read current memory stats for the zkCNN process
                VM_PEAK=$(grep "VmPeak:" /proc/$pid/status | awk '{print $2}')
                VM_HWM=$(grep "VmHWM:" /proc/$pid/status | awk '{print $2}')

                # Remove ' kB' suffix and convert to numbers
                VM_PEAK_NUM=${VM_PEAK% kB}
                VM_HWM_NUM=${VM_HWM% kB}

                # Update maximums using file-based communication
                if [ "$VM_PEAK_NUM" -gt "$MAX_VM_PEAK_KB" ] 2>/dev/null; then
                    echo "$VM_PEAK_NUM" > "${log_file}.peak"
                fi
                if [ "$VM_HWM_NUM" -gt "$MAX_VM_HWM_KB" ] 2>/dev/null; then
                    echo "$VM_HWM_NUM" > "${log_file}.hwm"
                fi

                # Log timestamp and memory values
                echo "$(date +%s) $VM_PEAK_NUM $VM_HWM_NUM" >> "$log_file"
            else
                # Process no longer exists, exit monitoring
                break
            fi
            sleep 1
        done
    } >/dev/null 2>&1
}

# Function to start memory monitoring for a specific PID
start_memory_monitoring() {
    local pid=$1
    monitor_memory "$pid" "$MEMORY_LOG_FILE" &
    MONITOR_PID=$!
    ZKCNN_PID=$pid
}

# Cleanup function
cleanup() {
    # Kill memory monitor if still running
    if [ ! -z "$MONITOR_PID" ]; then
        kill $MONITOR_PID 2>/dev/null
        wait $MONITOR_PID 2>/dev/null
    fi

    # Read final memory values from files
    if [ -f "${MEMORY_LOG_FILE}.peak" ]; then
        MAX_VM_PEAK_KB=$(cat "${MEMORY_LOG_FILE}.peak" 2>/dev/null || echo "0")
    fi
    if [ -f "${MEMORY_LOG_FILE}.hwm" ]; then
        MAX_VM_HWM_KB=$(cat "${MEMORY_LOG_FILE}.hwm" 2>/dev/null || echo "0")
    fi

    # Print memory statistics
    echo ""
    echo "=================================================="
    echo "Memory Usage Statistics"
    echo "=================================================="
    if [ "$MAX_VM_PEAK_KB" -gt 0 ]; then
        MAX_VM_PEAK_MB=$((MAX_VM_PEAK_KB / 1024))
        echo "Peak Virtual Memory (VmPeak): ${MAX_VM_PEAK_MB} MB"
    else
        echo "Peak Virtual Memory (VmPeak): Not recorded"
    fi
    if [ "$MAX_VM_HWM_KB" -gt 0 ]; then
        MAX_VM_HWM_MB=$((MAX_VM_HWM_KB / 1024))
        echo "Peak Physical Memory (VmHWM): ${MAX_VM_HWM_MB} MB"
    else
        echo "Peak Physical Memory (VmHWM): Not recorded"
    fi

    # Clean up log files
    rm -f "$MEMORY_LOG_FILE" "${MEMORY_LOG_FILE}.peak" "${MEMORY_LOG_FILE}.hwm" 2>/dev/null
    echo "=================================================="
}

# Set trap to cleanup on exit
trap cleanup EXIT

# ==================================================
# Network Configuration Parameters
# ==================================================
FC_INPUT_OUTPUT_SIZE=${1:-1024}  # Size of input/output vectors (n in n×n layers) (default: 1024)
FC_NUM_LAYERS=${2:-16}           # Number of fully connected layers (default: 16)
FC_MAX_THREADS=${3:-0}         # Maximum number of parallel threads (0 = auto-detect CPU cores)

# Auto-detect CPU cores if max_threads is 0
if [ "$FC_MAX_THREADS" -eq 0 ]; then
    if command -v nproc >/dev/null 2>&1; then
        FC_MAX_THREADS=$(nproc)
    elif [ -f /proc/cpuinfo ]; then
        FC_MAX_THREADS=$(grep -c '^processor' /proc/cpuinfo)
    else
        FC_MAX_THREADS=4  # fallback default
    fi
    echo "Auto-detected CPU cores: $FC_MAX_THREADS"
fi

# Validate parameters
if [ "$FC_INPUT_OUTPUT_SIZE" -lt 1 ] || [ "$FC_INPUT_OUTPUT_SIZE" -gt 1024 ]; then
    echo "Error: FC_INPUT_OUTPUT_SIZE must be between 1 and 1024"
    exit 1
fi

if [ "$FC_NUM_LAYERS" -lt 1 ] || [ "$FC_NUM_LAYERS" -gt 1024 ]; then
    echo "Error: FC_NUM_LAYERS must be between 1 and 1024"
    exit 1
fi

if [ "$FC_MAX_THREADS" -lt 1 ] || [ "$FC_MAX_THREADS" -gt 256 ]; then
    echo "Error: FC_MAX_THREADS must be between 1 and 256"
    exit 1
fi

echo "=================================================="
echo "zkCNN MLP Network Configuration"
echo "=================================================="
echo "Command: $0 $@"
echo "Network structure: X_{i+1} = σ(W_i X_i + b_i)"
echo "Each layer: ${FC_INPUT_OUTPUT_SIZE}×${FC_INPUT_OUTPUT_SIZE} weights + ${FC_INPUT_OUTPUT_SIZE} biases"
echo "Number of layers: $FC_NUM_LAYERS"
echo "Input/Output size: $FC_INPUT_OUTPUT_SIZE"
echo "Max threads: $FC_MAX_THREADS"
echo "Memory monitoring: ENABLED (1s intervals)"
echo "=================================================="

./build.sh
/usr/bin/cmake --build ../cmake-build-release --target demo_mlp_run -- -j 6

run_file=../cmake-build-release/src/demo_mlp_run
out_file=../output/single/demo-result-mlp${FC_NUM_LAYERS}.txt

mkdir -p ../output/single
mkdir -p ../log/single

# Data files
fc_i=../data/mlp${FC_INPUT_OUTPUT_SIZE}x${FC_NUM_LAYERS}/mlp${FC_INPUT_OUTPUT_SIZE}x${FC_NUM_LAYERS}-input-weights.csv
fc_c=../data/mlp${FC_INPUT_OUTPUT_SIZE}x${FC_NUM_LAYERS}/mlp${FC_INPUT_OUTPUT_SIZE}x${FC_NUM_LAYERS}-scale-zeropoint.csv
fc_o=../output/single/mlp${FC_INPUT_OUTPUT_SIZE}x${FC_NUM_LAYERS}-output.csv

echo "Demo: $FC_NUM_LAYERS-layer MLP network (${FC_INPUT_OUTPUT_SIZE}x${FC_INPUT_OUTPUT_SIZE} layers)"
echo "Network structure: X_{i+1} = σ(W_i X_i + b_i)"
echo "Each layer: ${FC_INPUT_OUTPUT_SIZE}x${FC_INPUT_OUTPUT_SIZE} weights + $FC_INPUT_OUTPUT_SIZE biases"

# Calculate total parameters
PARAMS_PER_LAYER=$((FC_INPUT_OUTPUT_SIZE * FC_INPUT_OUTPUT_SIZE + FC_INPUT_OUTPUT_SIZE))
TOTAL_PARAMS=$((FC_NUM_LAYERS * PARAMS_PER_LAYER))
echo "Total parameters: $FC_NUM_LAYERS layers × $PARAMS_PER_LAYER = $TOTAL_PARAMS params"
echo ""

# Create data directory if it doesn't exist
mkdir -p ../data/mlp${FC_INPUT_OUTPUT_SIZE}x${FC_NUM_LAYERS}

# Generate test data if it doesn't exist
if [ ! -f "$fc_i" ]; then
    echo "Generating test data for $FC_NUM_LAYERS-layer MLP network (${FC_INPUT_OUTPUT_SIZE}x${FC_INPUT_OUTPUT_SIZE})..."

    # Set environment variables for Python
    export FC_INPUT_OUTPUT_SIZE FC_NUM_LAYERS fc_i fc_c

    python3 -c "
import numpy as np
import os
import multiprocessing as mp
from concurrent.futures import ProcessPoolExecutor
import time

# 从环境变量获取参数
n = int(os.environ['FC_INPUT_OUTPUT_SIZE'])
layers = int(os.environ['FC_NUM_LAYERS'])
fc_i = os.environ['fc_i']
fc_c = os.environ['fc_c']

print(f'Generating int8 data for {layers} layers of {n}x{n}...')

def generate_layer_weights(layer_idx):
    '''生成单层权重和偏置'''
    # W_i (n x n)
    W = np.random.randint(-128, 128, size=(n, n)).astype(np.float32)
    # b_i (n x 1)
    b = np.random.randint(-128, 128, size=(n,)).astype(np.float32)
    return layer_idx, W.flatten(), b

start_time = time.time()

# 使用 int8 范围的整数 (-128 到 127)
# 1. 输入向量 X_0 (n x 1)
input_vec = np.random.randint(-128, 128, size=(n,)).astype(np.float32)

# 2. 并行生成权重和偏置
print(f'Using {min(mp.cpu_count(), layers)} processes for parallel generation...')

params = []
layer_indices = list(range(layers))

with ProcessPoolExecutor(max_workers=min(mp.cpu_count(), layers)) as executor:
    # 提交所有层的生成任务
    futures = [executor.submit(generate_layer_weights, i) for i in layer_indices]

    # 按顺序收集结果
    results = [None] * layers
    for future in futures:
        layer_idx, W_flat, b = future.result()
        results[layer_idx] = (W_flat, b)

    # 按层顺序合并参数
    for W_flat, b in results:
        params.extend(W_flat)
        params.extend(b)

# 合并所有数据
all_data = np.concatenate([input_vec, np.array(params)])

# 使用制表符分隔
np.savetxt(fc_i, all_data.reshape(1, -1), delimiter='\t', fmt='%.1f')

# 3. 配置文件 (虽然 zkCNN 内部动态计算，但仍生成一个占位)
config_data = np.array([[1.0, 0.0]], dtype=np.float32)
np.savetxt(fc_c, config_data, delimiter='\t', fmt='%.1f')

elapsed_time = time.time() - start_time
print(f'Data generation complete. Total elements: {len(all_data)}')
print(f'Parallel generation time: {elapsed_time:.2f} seconds')
"
fi

echo "Running $FC_NUM_LAYERS-layer MLP network proof generation..."
echo "Network structure: X_{i+1} = σ(W_i X_i + b_i) for each layer"
echo "Using $FC_MAX_THREADS threads for data generation (proof uses pic_cnt=1)"
echo "Memory monitoring active (check every 1 second)"
# pic_cnt is the 4th argument of the binary; keep it 1 (one input) to match generated data
# We pass n and num_layers as 5th/6th arguments to configure the circuit

# Start zkCNN program and monitor its memory usage
echo "Starting zkCNN program..."
${run_file} ${fc_i} ${fc_c} ${fc_o} 1 ${FC_INPUT_OUTPUT_SIZE} ${FC_NUM_LAYERS} > ${out_file} &
ZKCNN_PID=$!

# Wait a moment for the process to start
sleep 2

# Start memory monitoring for the zkCNN process
if kill -0 $ZKCNN_PID 2>/dev/null; then
    echo "Starting memory monitoring for PID $ZKCNN_PID..."
    start_memory_monitoring $ZKCNN_PID
else
    echo "Warning: zkCNN process failed to start"
fi

# Wait for the program to finish
wait $ZKCNN_PID 2>/dev/null
exit_code=$?

# Stop memory monitoring
if [ ! -z "$MONITOR_PID" ]; then
    kill $MONITOR_PID 2>/dev/null
    wait $MONITOR_PID 2>/dev/null
fi

# Print completion message
echo ""
echo "=================================================="
echo "Proof generation completed!"
echo "=================================================="
echo "Network configuration:"
echo "  - Layers: $FC_NUM_LAYERS"
echo "  - Input/Output size per layer: $FC_INPUT_OUTPUT_SIZE"
echo "  - Each layer: ${FC_INPUT_OUTPUT_SIZE}x${FC_INPUT_OUTPUT_SIZE} weights + $FC_INPUT_OUTPUT_SIZE biases"
echo "  - Total parameters: $TOTAL_PARAMS"
echo "  - Max threads: $FC_MAX_THREADS"
echo ""
echo "Output files:"
echo "  - Results: ${out_file}"
echo "  - Inference: ${fc_o}"

# Cleanup will be called automatically by trap EXIT
# Return the exit code
exit $exit_code
