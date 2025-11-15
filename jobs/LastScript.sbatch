#!/bin/bash
#SBATCH --job-name=LastScript
#SBATCH --output=openfoam_%j.out
#SBATCH --error=openfoam_%j.err
#SBATCH --ntasks=16
#SBATCH --time=02:00:00
#SBATCH --partition=normal

# ===========================================
#  OpenFOAM parallel run with RAPL power logging and convergence check
# ===========================================

set -euo pipefail
IFS=$'\n\t'

# --- SLURM defaults ---
SLURM_NTASKS=${SLURM_NTASKS:-16}
JOB_NAME=${SLURM_JOB_NAME:-OpenFOAM_Job}
NODELIST=$(scontrol show hostnames 2>/dev/null || hostname)

# --- Timestamped output directory ---
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTDIR="$(pwd)/results/run_${TIMESTAMP}"
mkdir -p "$OUTDIR"
echo "[$(date)] Starting OpenFOAM job: $JOB_NAME"
echo "Output directory: $OUTDIR"

# --- Load OpenFOAM environment ---
: "${WM_PROJECT_DIR:=}"
if [ -z "$WM_PROJECT_DIR" ]; then
    if [ -f /home/charles/OpenFOAM/OpenFOAM-v2412/etc/bashrc ]; then
        source /home/charles/OpenFOAM/OpenFOAM-v2412/etc/bashrc
    else
        echo "OpenFOAM environment not found. Exiting."
        exit 1
    fi
fi

# --- Copy minimal case ---
rsync -a --delete --exclude 'processor*' --exclude '*.out' --exclude '*.log' \
    0 constant system "$OUTDIR/" >/dev/null 2>&1 || true
cd "$OUTDIR" || { echo "Failed to cd to $OUTDIR"; exit 1; }

# --- Dynamic decomposeParDict ---
mkdir -p system
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
decomposePar -force > decompose.out 2>&1 || true

# --- CPU performance governor ---
if command -v cpupower >/dev/null 2>&1; then
    sudo cpupower frequency-set -g performance >/dev/null 2>&1 || true
fi

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
[[ -f "$RAPL_FILE" ]] || { echo "RAPL energy file not found. Exiting."; exit 1; }

WRAP_ADD=0
if [[ -n "$MAX_ENERGY_FILE" ]]; then
    max_range=$(awk '{print int($1)}' "$MAX_ENERGY_FILE" 2>/dev/null || echo 0)
    [[ $max_range -gt 0 ]] && WRAP_ADD=$max_range
fi

TMP_LOG="$(mktemp /tmp/power_rapl_${TIMESTAMP}_XXXXXX.csv)"
: > "$TMP_LOG"
chmod 600 "$TMP_LOG"
echo "timestamp_unix,energy_uj" > "$TMP_LOG"

POW_PID=""
cleanup() {
    [[ -n "$POW_PID" ]] && kill "$POW_PID" 2>/dev/null || true
    cp "$TMP_LOG" "$OUTDIR/power_rapl.csv" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# --- Start RAPL logging ---
(
    while true; do
        echo "$(date +%s),$(cat "$RAPL_FILE" 2>/dev/null || echo 0)" >> "$TMP_LOG"
        sleep 1
    done
) &
POW_PID=$!

START_E=$(cat "$RAPL_FILE" 2>/dev/null || echo 0)
START_T=$(date +%s)

# --- Run solver ---
echo "Running simpleFoam on $SLURM_NTASKS MPI tasks..."
if command -v srun >/dev/null 2>&1 && [ -n "${SLURM_JOB_ID:-}" ]; then
    srun --mpi=pmix -n "$SLURM_NTASKS" simpleFoam -parallel > foam.out 2>&1 || true
elif command -v mpirun >/dev/null 2>&1; then
    mpirun -np "$SLURM_NTASKS" --bind-to core simpleFoam -parallel > foam.out 2>&1 || true
else
    echo "No MPI launcher found. Exiting."
    exit 1
fi

END_E=$(cat "$RAPL_FILE" 2>/dev/null || echo 0)
END_T=$(date +%s)
ELAPSED=$((END_T - START_T))

# --- Handle RAPL wrap-around ---
if [[ "$END_E" -lt "$START_E" && $WRAP_ADD -gt 0 ]]; then
    END_E=$((END_E + WRAP_ADD))
fi

ENERGY_J=$(awk -v s="$START_E" -v e="$END_E" 'BEGIN{printf "%.2f", (e-s)/1e6}')
AVG_POWER=$(awk -v E="$ENERGY_J" -v T="$ELAPSED" 'BEGIN{if(T>0) printf "%.2f", E/T; else print "0"}')

# --- Iterations and convergence ---
ITERATIONS=$(grep -c "^Time = " foam.out 2>/dev/null || echo 0)
MAX_RESIDUAL=$(grep -i "Final residual" foam.out | awk '{print $NF}' | sort -nr | head -n1 || echo "N/A")
CONVERGED="No"
if [[ "$MAX_RESIDUAL" != "N/A" ]]; then
    IS_CONV=$(awk -v r="$MAX_RESIDUAL" 'BEGIN {if(r<1e-6) print 1; else print 0}')
    [[ "$IS_CONV" -eq 1 ]] && CONVERGED="Yes"
fi

EFF_S_PER_J=$(awk -v E="$ENERGY_J" -v T="$ELAPSED" 'BEGIN{if(E>0) printf "%.6f", T/E; else print "0"}')
ITER_PER_J=$(awk -v I="$ITERATIONS" -v E="$ENERGY_J" 'BEGIN{if(E>0) printf "%.6f", I/E; else print "0"}')

# --- Write summary ---
cat <<EOF > "$OUTDIR/efficiency_summary.txt"
=== OpenFOAM Energy Efficiency Summary ===
Timestamp: $(date -u)
Host: $(hostname)
Node list: $NODELIST
Job name: $JOB_NAME
MPI tasks: $SLURM_NTASKS
Solver: simpleFoam
Elapsed time (s): $ELAPSED
Total energy (J): $ENERGY_J
Average power (W): $AVG_POWER
Iterations (approx): $ITERATIONS
Max residual: $MAX_RESIDUAL
Converged: $CONVERGED
Efficiency (s/J): $EFF_S_PER_J
Iterations/J: $ITER_PER_J
EOF

echo "=== Run Complete ==="
echo "Results stored in: $OUTDIR"

