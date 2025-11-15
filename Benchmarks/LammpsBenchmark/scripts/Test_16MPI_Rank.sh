#!/usr/bin/env bash
# ===========================================
# LAMMPS parallel benchmark (Energy Mode)
# with RAPL power logging and performance summary
# ===========================================

set -euo pipefail
IFS=$'\n\t'

# --- SLURM / job defaults ---
SLURM_NTASKS=${SLURM_NTASKS:-16}
JOB_NAME=${SLURM_JOB_NAME:-LAMMPS_Energy}
NODELIST=$(scontrol show hostnames 2>/dev/null || hostname)

# --- Timestamped output directory ---
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTDIR="$(pwd)/results/run_${TIMESTAMP}"
mkdir -p "$OUTDIR"

echo "[$(date)] Starting LAMMPS job: $JOB_NAME"
echo "Output directory: $OUTDIR"

# --- Copy input files ---
INPUT_FILE="in.lj"
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "LAMMPS input file ($INPUT_FILE) not found."
    exit 1
fi
cp -r "$INPUT_FILE" "$OUTDIR/"
cd "$OUTDIR"

# ======================================================
# ENERGY-EFFICIENT TUNING BLOCK
# ======================================================

echo "[EnergyMode] Tuning CPU governor to powersave..."
for CPU in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo powersave | sudo tee "$CPU" >/dev/null
done

echo "[EnergyMode] Skipping aggressive MPI binding (let OS schedule)..."

# ======================================================
# END TUNING BLOCK
# ======================================================

# --- RAPL setup ---
RAPL_BASE="/sys/class/powercap/intel-rapl"
RAPL_FILE=""
MAX_ENERGY_FILE=""

for d in "$RAPL_BASE"/intel-rapl:*; do
    if [ -f "$d/energy_uj" ]; then
        RAPL_FILE="$d/energy_uj"
        [[ -f "$d/max_energy_range_uj" ]] && MAX_ENERGY_FILE="$d/max_energy_range_uj"
        break
    fi
done

[[ -f "$RAPL_FILE" ]] || { echo "RAPL not found."; exit 1; }

WRAP_ADD=0
if [[ -n "$MAX_ENERGY_FILE" ]]; then
    max_range=$(awk '{print int($1)}' "$MAX_ENERGY_FILE" 2>/dev/null || echo 0)
    [[ $max_range -gt 0 ]] && WRAP_ADD=$max_range
fi

TMP_LOG="$(mktemp -u /dev/shm/power_rapl_${TIMESTAMP}_XXXXXX.csv 2>/dev/null || mktemp /tmp/power_rapl_${TIMESTAMP}_XXXXXX.csv)"
: > "$TMP_LOG"
chmod 600 "$TMP_LOG"
echo "timestamp_unix,energy_uj" > "$TMP_LOG"

POW_PID=""
cleanup() {
    if [[ -n "${POW_PID:-}" ]]; then
        kill "$POW_PID" 2>/dev/null || true
        wait "$POW_PID" 2>/dev/null || true
    fi
    cp -f "$TMP_LOG" "$OUTDIR/power_rapl.csv" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# --- Start RAPL logging ---
(
    while true; do
        echo "$(date +%s),$(cat "$RAPL_FILE")" >> "$TMP_LOG"
        sleep 1
    done
) &
POW_PID=$!

START_E=$(cat "$RAPL_FILE")
START_T=$(date +%s)

# --- Run LAMMPS ---
echo "Running LAMMPS (Energy Mode) on $SLURM_NTASKS tasks..."

LAMMPS_BIN="/home/debugthugz_shared/productivity_to_energy/productivity-to-energy-ratio-for-HPC-applications/benchmarks/Lamps/lammps/bench/lmp_mpi"

if command -v mpirun >/dev/null 2>&1; then
    mpirun -np "$SLURM_NTASKS" "$LAMMPS_BIN" -in "$INPUT_FILE" > lammps.out 2>&1 || true
else
    echo "mpirun not found."
    exit 1
fi

END_E=$(cat "$RAPL_FILE")
END_T=$(date +%s)
ELAPSED=$((END_T - START_T))

if [[ "$END_E" -lt "$START_E" && $WRAP_ADD -gt 0 ]]; then
    END_E=$((END_E + WRAP_ADD))
fi

ENERGY_J=$(awk -v s="$START_E" -v e="$END_E" 'BEGIN {printf "%.2f",(e-s)/1e6}')
AVG_POWER=$(awk -v E="$ENERGY_J" -v T="$ELAPSED" 'BEGIN{if(T>0) printf "%.2f",E/T; else print "0.00"}')

# Extract LAMMPS performance safely
STEPS=$(grep -E "Loop time of" lammps.out | awk '{print $(NF-8)}' || echo "0")
TIMESTEP_RATE=$(grep -E "timesteps/s" lammps.out | awk '{print $(NF-1)}' || echo "0")
ATOM_RATE=$(grep -E "Matom-step/s" lammps.out | awk '{print $1}' || echo "0")

# Avoid division by zero
EFF_S_PER_J="0"
if (( $(echo "$ENERGY_J > 0" | bc -l) )); then
    EFF_S_PER_J=$(awk -v E="$ENERGY_J" -v T="$ELAPSED" 'BEGIN{printf "%.6f",T/E}')
fi

{
echo "=== LAMMPS Energy-mode Summary ==="
echo "Timestamp: $(date -u)"
echo "Host: $(hostname)"
echo "Node list: $NODELIST"
echo "Job name: $JOB_NAME"
echo "MPI tasks: $SLURM_NTASKS"
echo "Elapsed time (s): $ELAPSED"
echo "Total energy (J): $ENERGY_J"
echo "Average power (W): $AVG_POWER"
echo "LAMMPS Steps: $STEPS"
echo "Performance (timesteps/s): $TIMESTEP_RATE"
echo "Performance (M atom-step/s): $ATOM_RATE"
echo "Efficiency (s/J): $EFF_S_PER_J"
} > "$OUTDIR/efficiency_summary.txt"

echo "=== DONE (Energy Mode) ==="
echo "Results stored in: $OUTDIR"

