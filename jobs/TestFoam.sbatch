#!/bin/bash
#SBATCH --job-name=OpenFOAM_Run       
#SBATCH --output=slurm_%j.out         
#SBATCH --error=slurm_%j.err          
#SBATCH --nodes=1                      
#SBATCH --ntasks=4                     
#SBATCH --time=02:00:00                
#SBATCH --partition=normal
#SBATCH --exclusive                  

# ==============================
# SLURM OpenFOAM Parallel Run + RAPL Power Logging + Efficiency Calculation
# ==============================

set -euo pipefail
IFS=$'\n\t'

# Load OpenFOAM environment
source /home/charles/OpenFOAM/OpenFOAM-v2412/etc/bashrc

# Number of MPI tasks
SLURM_NTASKS=${SLURM_NTASKS:-4}

# Timestamped results folder
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTDIR="results/run_$TIMESTAMP"
mkdir -p "$OUTDIR"

echo "Running OpenFOAM case. Outputs will be in $OUTDIR"

# Copy case files (exclude intermediate and log files)
rsync -a --exclude 'processor*' --exclude 'foam.out' --exclude 'decompose.out' ./ "$OUTDIR/"
cd "$OUTDIR" || exit 1

# -----------------------------
# Create decomposeParDict dynamically
# -----------------------------
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

# Decompose mesh for parallel run
decomposePar -force > decompose.out 2>&1

# -----------------------------
# Start RAPL power logging
# -----------------------------
RAPL_FILE="/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj"

if [ ! -f "$RAPL_FILE" ]; then
    echo "Error: RAPL file not found ($RAPL_FILE). Exiting."
    exit 1
fi

echo "Starting RAPL energy logging..."
(
    while true; do
        ts=$(date +"%Y-%m-%d %H:%M:%S")
        e=$(cat "$RAPL_FILE" 2>/dev/null || echo 0)
        echo "$ts,$e"
        sleep 1
    done
) > "$OUTDIR/power_rapl.csv" &
POW_PID=$!

# Record start time and initial energy
START_TIME=$(date +%s)
START_ENERGY=$(cat "$RAPL_FILE")

# -----------------------------
# Run OpenFOAM Solver using SLURM srun
# -----------------------------
echo "Running simpleFoam on $SLURM_NTASKS MPI tasks..."
srun --mpi=pmix -n "$SLURM_NTASKS" simpleFoam -parallel > foam.out 2>&1

# -----------------------------
# Stop RAPL logging
# -----------------------------
kill $POW_PID 2>/dev/null
wait $POW_PID 2>/dev/null

# Record end time and energy
END_TIME=$(date +%s)
END_ENERGY=$(cat "$RAPL_FILE")
ELAPSED=$((END_TIME - START_TIME))

# -----------------------------
# Compute Energy & Efficiency
# -----------------------------
ENERGY_J=$(awk -v start="$START_ENERGY" -v end="$END_ENERGY" 'BEGIN{printf "%.2f", (end-start)/1e6}')
AVG_POWER_W=$(awk -v e="$ENERGY_J" -v t="$ELAPSED" 'BEGIN{if(t>0) printf "%.2f", e/t; else print "0"}')

ITERATIONS=$(grep -c "Time =" foam.out)
EFFICIENCY_S_PER_J=$(awk -v e="$ENERGY_J" -v t="$ELAPSED" 'BEGIN{if(e>0) printf "%.6f", t/e; else print "0"}')
ITER_PER_J=$(awk -v i="$ITERATIONS" -v e="$ENERGY_J" 'BEGIN{if(e>0) printf "%.6f", i/e; else print "0"}')

# -----------------------------
# Save Summary
# -----------------------------
{
    echo "=== OpenFOAM Energy Efficiency Summary ==="
    echo "Timestamp: $(date)"
    echo "Run Directory: $OUTDIR"
    echo "Solver: simpleFoam"
    echo "MPI Tasks: $SLURM_NTASKS"
    echo "Elapsed Time: ${ELAPSED}s"
    echo "Total Energy: ${ENERGY_J} J"
    echo "Average Power: ${AVG_POWER_W} W"
    echo "Total Iterations: ${ITERATIONS}"
    echo "Efficiency (Time per Energy): ${EFFICIENCY_S_PER_J} s/J"
    echo "Iterations per Joule: ${ITER_PER_J} it/J"
} > "$OUTDIR/efficiency_summary.txt"

echo "=== OpenFOAM run finished ==="
echo "Results saved in: $OUTDIR"
echo "Summary available at: $OUTDIR/efficiency_summary.txt"

