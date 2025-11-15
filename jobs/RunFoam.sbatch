#!/bin/bash
#SBATCH --job-name=RunFoam
#SBATCH --output=openfoam_perf_%j.out
#SBATCH --error=openfoam_perf_%j.err
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=1
#SBATCH --time=02:00:00
#SBATCH --partition=normal
#SBATCH --hint=nomultithread

# ==============================
# OpenFOAM Performance-Optimized SLURM Job
# ==============================

set -euo pipefail

# Load OpenFOAM environment
source /home/charles/OpenFOAM/OpenFOAM-v2412/etc/bashrc

# Default config (override via sbatch --export=SLURM_NTASKS=...)
: ${SLURM_NTASKS:=4}
: ${OMP_NUM_THREADS:=1}
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTDIR="results/run_$TIMESTAMP"
RAPL_INTERVAL=0.1
HOSTNAME=$(hostname)

# Performance tuning
export OMP_PROC_BIND=close
export OMP_PLACES=cores
export KMP_AFFINITY=compact,1,0,granularity=fine
export UCX_NET_DEVICES=all

mkdir -p "$OUTDIR"
echo "Running OpenFOAM case. Outputs will be in $OUTDIR"

# System information
{
    echo "=== System Information ==="
    lscpu
    echo -e "\n=== Memory Info ==="
    free -h
    echo -e "\n=== OpenFOAM Version ==="
    simpleFoam -version 2>&1
    echo -e "\n=== MPI Version ==="
    mpirun --version
} > "$OUTDIR/system_info.txt"

# Copy case files
rsync -a --exclude 'processor*' --exclude '*.log' --exclude '*.csv' --exclude '*.out' ./ "$OUTDIR/"
cd "$OUTDIR" || exit 1

# Generate optimized decomposeParDict
cat > system/decomposeParDict <<EOF
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    object      decomposeParDict;
}
numberOfSubdomains $SLURM_NTASKS;
method          scotch;
EOF

# Decompose mesh
/usr/bin/time -v decomposePar -force > "$OUTDIR/decompose.log" 2>&1

# -----------------------------
# Performance Monitoring Functions
# -----------------------------
start_monitoring() {
    RAPL_FILE="/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj"
    if [ -f "$RAPL_FILE" ]; then
        {
            echo "timestamp,energy_uj"
            while true; do
                echo "$(date +%s.%N),$(cat "$RAPL_FILE" 2>/dev/null || echo 0)"
                sleep "$RAPL_INTERVAL"
            done
        } > "$OUTDIR/power_rapl.csv" &
        RAPL_PID=$!
    fi
    # CPU monitoring
    {
        echo "timestamp,%usr,%sys,%iowait,%idle"
        mpstat -P ALL 1 | stdbuf -oL grep -v "Average" | stdbuf -oL grep -v "CPU" | \
        stdbuf -oL awk '/^[0-9]/ {print systime()","$3","$5","$6","$12}'
    } > "$OUTDIR/cpu_usage.csv" &
    CPU_PID=$!
    # Memory monitoring
    {
        echo "timestamp,used,free,buffers,cached"
        while true; do
            free -k | awk 'NR==2{print systime()","$3","$4","$6","$7}'
            sleep 1
        done
    } > "$OUTDIR/memory_usage.csv" &
    MEM_PID=$!
}

stop_monitoring() {
    kill "$RAPL_PID" "$CPU_PID" "$MEM_PID" 2>/dev/null || true
    wait 2>/dev/null
}

# -----------------------------
# Run Simulation
# -----------------------------
echo "=== Starting Simulation ==="
start_monitoring
START_TIME=$(date +%s.%N)

mpirun -np $SLURM_NTASKS \
    --bind-to core \
    --map-by socket:PE=$OMP_NUM_THREADS \
    -x OMP_NUM_THREADS \
    -x OMP_PROC_BIND \
    -x OMP_PLACES \
    -x KMP_AFFINITY \
    simpleFoam -parallel > "$OUTDIR/foam.out" 2>&1

END_TIME=$(date +%s.%N)
stop_monitoring
ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)

# -----------------------------
# Performance Analysis
# -----------------------------
# Energy usage
if [ -f "$OUTDIR/power_rapl.csv" ]; then
    START_ENERGY=$(head -n 2 "$OUTDIR/power_rapl.csv" | tail -1 | cut -d',' -f2)
    END_ENERGY=$(tail -n 1 "$OUTDIR/power_rapl.csv" | cut -d',' -f2)
    ENERGY_J=$(echo "scale=2; ($END_ENERGY - $START_ENERGY) / 1000000" | bc)
else
    ENERGY_J=0
fi

ITERATIONS=$(grep -c "Time =" "$OUTDIR/foam.out")
AVG_POWER_W=$(echo "scale=2; $ENERGY_J / $ELAPSED" | bc)
EFFICIENCY=$(echo "scale=6; $ITERATIONS / $ENERGY_J" | bc)
CPU_AVG=$(mpstat 1 1 | awk 'END{print 100 - $NF}')
MEM_USED=$(free -m | awk 'NR==2{print $3}')

# -----------------------------
# Generate Reports
# -----------------------------
cat > "$OUTDIR/performance_report.json" <<EOF
{
  "metadata": {
    "hostname": "$HOSTNAME",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "mpi_tasks": $SLURM_NTASKS,
    "omp_threads": $OMP_NUM_THREADS
  },
  "performance": {
    "elapsed_time": $ELAPSED,
    "iterations": $ITERATIONS,
    "iterations_per_second": $(echo "scale=2; $ITERATIONS / $ELAPSED" | bc),
    "energy_consumed_j": $ENERGY_J,
    "average_power_w": $AVG_POWER_W,
    "efficiency_iter_per_j": $EFFICIENCY,
    "cpu_utilization": $CPU_AVG,
    "memory_used_mb": $MEM_USED
  }
}
EOF

# Human-readable summary
cat > "$OUTDIR/summary.txt" <<EOF
=== OpenFOAM Performance Run Summary ===
Timestamp:       $(date)
Host:            $HOSTNAME
MPI Tasks:       $SLURM_NTASKS
OMP Threads:     $OMP_NUM_THREADS
Elapsed Time:    $(printf "%.2f" $ELAPSED) seconds
Iterations:      $ITERATIONS
Iterations/s:    $(echo "scale=2; $ITERATIONS / $ELAPSED" | bc)
Energy:          $ENERGY_J J
Avg. Power:      $AVG_POWER_W W
Efficiency:      $EFFICIENCY it/J
CPU Utilization: $CPU_AVG%
Memory Used:     $MEM_USED MB
EOF

cat "$OUTDIR/summary.txt"

