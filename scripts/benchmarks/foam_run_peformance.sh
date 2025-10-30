#!/bin/bash
#SBATCH --job-name=simpleFoam_power
#SBATCH --output=res_%j.txt
#SBATCH --time=00:30:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=1
#SBATCH --exclusive

# Options: conservative ondemand userspace powersave performance schedutil
CPU_GOVERNOR="performance"  
CPU_FREQ_MIN="1200000"      
CPU_FREQ_MAX="3500000"      
CPU_FREQ_SET="2400000" 

# Power measurement interval (seconds)
POWER_SAMPLE_INTERVAL=5
. /home/charles/OpenFOAM/OpenFOAM-v2412/etc/bashrc
mkdir -p power_logs
POWER_LOG="power_logs/power_${SLURM_JOB_ID}.log"
METRICS_LOG="power_logs/metrics_${SLURM_JOB_ID}.log"

echo "=== Job Information ===" | tee -a $METRICS_LOG
echo "Job ID: $SLURM_JOB_ID" | tee -a $METRICS_LOG
echo "Nodes: $SLURM_JOB_NUM_NODES" | tee -a $METRICS_LOG
echo "Tasks: $SLURM_NTASKS" | tee -a $METRICS_LOG
echo "CPUs per task: $SLURM_CPUS_PER_TASK" | tee -a $METRICS_LOG
echo "Start time: $(date)" | tee -a $METRICS_LOG
echo "Governor: $CPU_GOVERNOR" | tee -a $METRICS_LOG

# Function to set CPU governor and frequency
set_cpu_parameters() {
    echo "=== Setting CPU Parameters ===" | tee -a $METRICS_LOG
    
    # Set governor for all CPUs
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -w "$cpu" ]; then
            echo $CPU_GOVERNOR > $cpu 2>/dev/null || \
            sudo cpupower frequency-set -g $CPU_GOVERNOR
        fi
    done
    
    # If using userspace governor, set specific frequency
    if [ "$CPU_GOVERNOR" = "userspace" ]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_setspeed; do
            if [ -w "$cpu" ]; then
                echo $CPU_FREQ_SET > $cpu 2>/dev/null || \
                sudo cpupower frequency-set -f ${CPU_FREQ_SET}kHz
            fi
        done
    fi

    echo "Current CPU frequencies:" | tee -a $METRICS_LOG
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null | tee -a $METRICS_LOG || \
    cpupower frequency-info | grep "current CPU frequency" | tee -a $METRICS_LOG
}


get_power_reading() {
    local power_value=""

    if [ -d "/sys/class/powercap/intel-rapl" ]; then
        local energy=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj 2>/dev/null)
        echo "RAPL:$energy"
        return 0
    fi
    echo "NONE:0"
    return 1
}

monitor_power() {
    local log_file=$1
    local interval=$2
    
    echo "Timestamp,Power_Reading,Method" > $log_file
    
    while [ -f /tmp/power_monitor_${SLURM_JOB_ID}.flag ]; do
        local timestamp=$(date +%s.%N)
        local power_data=$(get_power_reading)
        echo "$timestamp,$power_data" >> $log_file
        sleep $interval
    done
}

set_cpu_parameters

# Record initial power state
POWER_START=$(get_power_reading)
echo "Initial power reading: $POWER_START" | tee -a $METRICS_LOG

touch /tmp/power_monitor_${SLURM_JOB_ID}.flag
monitor_power $POWER_LOG $POWER_SAMPLE_INTERVAL &
MONITOR_PID=$!
echo "Power monitoring started (PID: $MONITOR_PID)" | tee -a $METRICS_LOG

echo "=== Starting OpenFOAM Decomposition ===" | tee -a $METRICS_LOG
DECOMP_START=$(date +%s)

echo "FoamFile" > system/decomposeParDict
echo "{"  >> system/decomposeParDict
echo "  version             2.0;" >> system/decomposeParDict
echo "  format            ascii;" >> system/decomposeParDict
echo "  class        dictionary;" >> system/decomposeParDict
echo "  object decomposeParDict;" >> system/decomposeParDict
echo "}"  >> system/decomposeParDict
echo "numberOfSubdomains " $SLURM_NTASKS ";" >> system/decomposeParDict
echo "method scotch;" >> system/decomposeParDict

decomposePar -force > decompose.out
DECOMP_END=$(date +%s)
DECOMP_TIME=$((DECOMP_END - DECOMP_START))
echo "Decomposition time: ${DECOMP_TIME} seconds" | tee -a $METRICS_LOG

echo "=== Starting OpenFOAM Simulation ===" | tee -a $METRICS_LOG
SIM_START=$(date +%s)

mpirun -np $SLURM_NTASKS --bind-to core simpleFoam -parallel > foam.out

SIM_END=$(date +%s)
SIM_TIME=$((SIM_END - SIM_START))
echo "Simulation time: ${SIM_TIME} seconds" | tee -a $METRICS_LOG

rm /tmp/power_monitor_${SLURM_JOB_ID}.flag
wait $MONITOR_PID
echo "Power monitoring stopped" | tee -a $METRICS_LOG

# Record final power state
POWER_END=$(get_power_reading)
echo "Final power reading: $POWER_END" | tee -a $METRICS_LOG

echo "=== Performance Metrics ===" | tee -a $METRICS_LOG
TOTAL_TIME=$((SIM_END - SIM_START))
echo "Total runtime: ${TOTAL_TIME} seconds" | tee -a $METRICS_LOG

# Extract iterations from OpenFOAM output
ITERATIONS=$(grep -i "Time =" foam.out | wc -l)
echo "Iterations completed: $ITERATIONS" | tee -a $METRICS_LOG

if [ $TOTAL_TIME -gt 0 ] && [ $ITERATIONS -gt 0 ]; then
    TIME_PER_ITER=$(echo "scale=3; $TOTAL_TIME / $ITERATIONS" | bc)
    echo "Time per iteration: ${TIME_PER_ITER} seconds" | tee -a $METRICS_LOG
fi

echo "End time: $(date)" | tee -a $METRICS_LOG
echo "Job completed successfully" | tee -a $METRICS_LOG
echo "Power log: $POWER_LOG" | tee -a $METRICS_LOG
echo "Metrics log: $METRICS_LOG" | tee -a $METRICS_LOG