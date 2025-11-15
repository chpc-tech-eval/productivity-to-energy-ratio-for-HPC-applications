#!/bin/bash
# MweLammps_Balance.sh
# Run LAMMPS in Balanced Mode and produce a full efficiency summary.

set -euo pipefail
IFS=$'\n\t'

# ---------------- User settings ----------------
LAMMPS_BIN="./lmp_mpi"
INPUT_FILE="in.lj"
MPI_TASKS=16
RESULTS_DIR="./results"

# ---------------- Prepare output directory ----------------
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTDIR="${RESULTS_DIR}/run_${TIMESTAMP}"
mkdir -p "$OUTDIR"

echo "[${TIMESTAMP}] Starting LAMMPS job: LAMMPS_Balanced"
echo "Output directory: $OUTDIR"

# ---------------- Run LAMMPS ----------------
echo "[BalancedMode] Tuning CPU governor to ondemand..."
sudo cpupower frequency-set -g ondemand &>/dev/null || true
echo "[BalancedMode] Letting OS schedule MPI tasks (no aggressive binding)."
mpirun -np $MPI_TASKS $LAMMPS_BIN -in $INPUT_FILE > "$OUTDIR/lammps.out"

echo "=== DONE (Balanced Mode) ==="

# ---------------- Parse LAMMPS output ----------------
OUTFILE="$OUTDIR/lammps.out"

# Total elapsed time
ELAPSED=$(grep "Loop time" "$OUTFILE" | awk '{print $4+0}') || ELAPSED=0

# Total LAMMPS steps
STEPS=$(grep "Loop time" "$OUTFILE" | awk '{print $9+0}') || STEPS=0

# Timesteps per second
TIMESTEPS_PER_S=$(grep "Performance:" "$OUTFILE" | awk '{print $4+0}') || TIMESTEPS_PER_S=0

# Million atom-steps per second
MATOMSTEP=$(grep "Performance:" "$OUTFILE" | awk '{print $6+0}') || MATOMSTEP=0

# Total energy: last TotEng value from table
TOTAL_ENERGY=$(awk '/TotEng/ {header=1; next} header {energy=$5} END {print energy+0}' "$OUTFILE") || TOTAL_ENERGY=0

# Calculate efficiency (s/J)
if (( $(echo "$TOTAL_ENERGY == 0" | bc -l) )); then
    EFFICIENCY="N/A"
else
    EFFICIENCY=$(echo "$ELAPSED / $TOTAL_ENERGY" | bc -l)
fi

# ---------------- Write summary ----------------
SUMMARY="$OUTDIR/efficiency_summary.txt"
{
echo "=== LAMMPS Balanced-mode Summary ==="
echo "Timestamp: $(date -u)"
echo "Host: $(hostname)"
echo "Node list: $(hostname)"
echo "Job name: LAMMPS_Balanced"
echo "MPI tasks: $MPI_TASKS"
echo "Elapsed (s): $ELAPSED"
echo "Total energy (J): $TOTAL_ENERGY"
echo "Average power (W): $(echo "$TOTAL_ENERGY / $ELAPSED" | bc -l)"
echo "LAMMPS Steps: $STEPS"
echo "Timesteps/s: $TIMESTEPS_PER_S"
echo "M atom-step/s: $MATOMSTEP"
echo "Efficiency (s/J): $EFFICIENCY"
} > "$SUMMARY"

echo "Efficiency summary saved to $SUMMARY"

