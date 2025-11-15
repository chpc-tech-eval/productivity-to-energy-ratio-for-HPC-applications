#!/bin/bash
# ============================================
#   FULL CLUSTER INFORMATION REPORT GENERATOR
# ============================================

OUT="cluster_report_$(hostname)_$(date +%Y%m%d_%H%M%S).txt"

echo "======================================================" | tee -a $OUT
echo "        CLUSTER SYSTEM INFORMATION REPORT" | tee -a $OUT
echo "   Host: $(hostname) | Date: $(date)" | tee -a $OUT
echo "======================================================" | tee -a $OUT

###############################################
### 1. BASIC SYSTEM INFO
###############################################
echo -e "\n### 1. BASIC SYSTEM INFO ####################################" | tee -a $OUT
hostname | tee -a $OUT
echo "Uptime:" | tee -a $OUT
uptime | tee -a $OUT
echo -e "\nOS Release:" | tee -a $OUT
cat /etc/os-release | tee -a $OUT

###############################################
### 2. CPU INFORMATION
###############################################
echo -e "\n### 2. CPU INFORMATION #######################################" | tee -a $OUT
lscpu | tee -a $OUT

echo -e "\nCPU Frequency (per core):" | tee -a $OUT
grep "cpu MHz" /proc/cpuinfo | tee -a $OUT

###############################################
### 3. MEMORY INFORMATION
###############################################
echo -e "\n### 3. MEMORY INFORMATION ####################################" | tee -a $OUT
free -h | tee -a $OUT

echo -e "\nDetailed Memory (dmidecode):" | tee -a $OUT
sudo dmidecode -t memory 2>/dev/null | tee -a $OUT

###############################################
### 4. GPU INFORMATION
###############################################
echo -e "\n### 4. GPU / ACCELERATOR INFO ###############################" | tee -a $OUT
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi -q | tee -a $OUT
else
    echo "No NVIDIA GPU detected or driver not installed." | tee -a $OUT
fi

###############################################
### 5. NETWORK INFORMATION
###############################################
echo -e "\n### 5. NETWORK INFORMATION ###################################" | tee -a $OUT
ip -br addr | tee -a $OUT

echo -e "\nFull NIC Info:" | tee -a $OUT
ip link | tee -a $OUT

echo -e "\nPCI Network Devices:" | tee -a $OUT
lspci | grep -i -e ethernet -e infiniband -e network | tee -a $OUT

###############################################
### 6. STORAGE INFORMATION
###############################################
echo -e "\n### 6. STORAGE INFORMATION ###################################" | tee -a $OUT
lsblk -o NAME,MAJ

