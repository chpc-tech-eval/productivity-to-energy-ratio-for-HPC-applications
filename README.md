# Project Title

**Mapping out the Productivity-to-Energy Cost Ratio for Different Applications Running on HPC Hardware**

**Capstone Project – CHPC Student Cluster Competition**

---

## Research Group

- **Team Name:** Debug Thugs
- **Institution:** Sol Plaatje University
- **Supervisors:** Charles Crosby, Mabatho Hashatsi & Mfundo Mdwadube (CHPC)
- **Cluster Access:** CHPC Lengau → Private Cluster (10.128.23.188)
- **Project Code:** DEVL1048

---

## 1. Project Overview

This project explores how different High-Performance Computing (HPC) applications perform across various hardware configurations and energy conditions. The primary goal is to understand the relationship between computational productivity (performance) and energy cost (power consumption) when running real-world scientific workloads.

By integrating performance benchmarking with energy monitoring, we aim to quantify how efficiently HPC systems convert electrical energy into useful computational output. The study will highlight performance–energy trade-offs, reveal efficiency trends, and propose strategies to optimize energy usage. Ultimately, the findings will support more energy-aware HPC operations, especially in research environments where both performance and sustainability are critical priorities.

---

## 2. Objectives

- **Benchmark multiple HPC applications** under controlled environments.
- **Measure both performance and energy consumption** at runtime.
- **Compute the productivity-to-energy cost ratio** to quantify the relationship between computational output and power usage.
- **Analyse performance trends** in relation to hardware configurations, system parameters, and optimization settings.
- **Develop methods or scripts** to dynamically adjust hardware parameters (e.g., CPU frequency, core allocation) to study energy-performance trade-offs.
- **Provide recommendations and best practices** for achieving optimal performance per unit of energy consumed in HPC environments.

---

## 3. Benchmark Selection

We will focus on three key benchmarks that represent both synthetic and real-world HPC workloads:

### **HPL (High-Performance Linpack)**
A **synthetic benchmark** designed to measure a system's peak floating-point performance (FLOPS). It is widely used to evaluate the theoretical maximum computational capability of HPC clusters.

### **OpenFOAM**
An **open-source Computational Fluid Dynamics (CFD)** application used for simulating fluid flow, turbulence, and heat transfer. It represents a complex, real-world engineering workload that tests both computation and memory performance.

### **ANSYS Fluent**
A **commercial CFD solver** used in engineering and scientific simulations involving fluid dynamics and heat transfer. It provides a realistic, industry-grade benchmark for assessing cluster performance and energy efficiency.

### Metrics Collected

- **Node power draw (Watts)** via IPMI or power sensors
- **Total energy consumption (kWh)** per benchmark
- **Execution time (seconds)** per workload
- **Productivity metrics** (FLOPS, throughput, performance score)
- **Productivity-to-energy ratio**:

$$
\text{Efficiency} = \frac{\text{Performance Metric}}{\text{Energy Consumption}}
$$

---

## 4. Methodology

### Step 1: Environment Setup

1. Obtain CHPC and Lengau login credentials via [https://users.chpc.ac.za](https://users.chpc.ac.za).
2. Access the allocated cluster through Lengau using SSH.
3. Install essential system dependencies and libraries:
   - **Compilers:** GCC, Intel oneAPI
   - **MPI Implementations:** OpenMPI, MPICH
   - **Math Libraries:** OpenBLAS, Intel MKL
   - **Schedulers & Managers:** Slurm, Munge
   - **Configuration Tools:** Ansible, Terraform
4. Validate connectivity and NFS mounting between nodes.

### Step 2: Application Installation & Verification

- Install **OpenFOAM** and **ANSYS Fluent** following official CHPC or vendor guidelines.
- Acquire benchmark datasets (provided by CHPC support scientists).
- Perform test runs on a single node to confirm installation success.
- Log and document all environment variables and dependency versions.

### Step 3: Benchmarking Execution

1. Use **Slurm** to schedule test jobs across multiple nodes.
2. Configure scripts to collect:
   - **Execution time** (wall time)
   - **CPU and memory usage**
   - **Power consumption** (using software tools or IPMI sensors)
3. Run each application multiple times under different system settings:
   - Vary **CPU clock frequencies**
   - Modify **number of cores per node**
   - Adjust **memory bandwidth policies**
   - Enable/disable **hyper-threading**
4. Record outputs, logs, and performance metrics for analysis.

### Step 4: Measuring Energy Consumption

- Evaluate two measurement strategies:
  1. **Software-based:** Using tools like `powermetrics`, `s-tui`, or querying `/sys/class/powercap/intel-rapl`.
  2. **Hardware-based:** Using node-integrated sensors or CHPC's external power meters.
- Compare the precision of both approaches.

### Step 5: Data Analysis

- Calculate the **Productivity-to-Energy Cost Ratio** using:

$$
\text{Ratio} = \frac{\text{Performance (FLOPS, iterations/s, or case completion time)}}{\text{Power (Watts)}}
$$

- Plot performance trends for each configuration using Python or MATLAB.
- Identify configurations that maximize performance per energy cost unit.

### Step 6: Dynamic Parameter Control

- Develop scripts to set system parameters dynamically using job scripts, for example:

```bash
#!/bin/bash
#SBATCH --nodes=2

module load openmpi
cpupower frequency-set -g performance
mpirun -np 64 ./benchmark_case
```

---

## 5. Tools, Technologies & Frameworks

This project utilizes a range of tools and frameworks for benchmarking, performance analysis, and energy monitoring within an HPC environment.

### Cluster Management and Automation

- **Slurm** – Job scheduling and workload management across compute nodes.
- **MUNGE** – Authentication service for secure communication between nodes.
- **Ansible** – Automation tool for consistent configuration and deployment management.

### Energy Monitoring

- **IPMI** – Hardware-level monitoring interface for power and temperature data.
- **powerstat** – Command-line tool for measuring system power consumption.
- **Node-level telemetry tools** – Collect fine-grained energy metrics from cluster nodes.

### Benchmarking Applications

We will focus on these key benchmarks that represent both synthetic and real-world HPC workloads:

- **HPL (High-Performance Linpack)** – Synthetic benchmark for peak floating-point performance.
- **OpenFOAM** – Open-source CFD application for fluid dynamics simulations.
- **ANSYS Fluent** – Commercial CFD solver for engineering-scale simulations.
- **HPCC (High-Performance Computing Challenge)** – Suite of tests assessing system memory, bandwidth, and latency.

### Performance Libraries

- **OpenMPI** – Message Passing Interface implementation for parallel computing.
- **OpenBLAS** – Optimized linear algebra library for high-performance matrix operations.
- **Intel oneAPI** – Toolkit providing compilers and performance libraries for heterogeneous HPC workloads.

### Programming and Data Analysis

- **Python**, **Bash**, and **Jupyter Notebooks** – Used for data collection, automation, and post-benchmark analysis.

### Visualization and Monitoring

- **Matplotlib** and **Seaborn** – For performance and energy data visualization.
- **Prometheus** and **Grafana** – For real-time cluster metrics and dashboard monitoring.

### Version Control

- **GitHub** – Centralized platform for collaborative development, documentation, and version control.

---

## 6. Expected Outcomes

- A comparative analysis of HPC application efficiency based on performance per watt.
- Graphical reports showing trends between energy consumption and computational throughput.
- Recommendations for improving energy efficiency in HPC clusters.
- A clear **performance-efficiency profile** for each benchmarked application.

---

## 7. Recommendations and Future Work

1. Implement **software-based dynamic tuning** for real-time performance adjustments.
2. Integrate **job-aware energy monitoring tools** to automate measurement.
3. Extend benchmarking to include **GPU-accelerated workloads** using CUDA or ROCm.
4. Compare **virtualized vs. bare-metal** energy profiles for the same workloads.
5. Publish results as a **case study** on sustainable HPC practices.

---

## 8. References

- CHPC User Documentation: [https://wiki.chpc.ac.za](https://wiki.chpc.ac.za)
- OpenFOAM Official Docs: [https://www.openfoam.com](https://www.openfoam.com)
- HPL & HPCC Benchmarks: [http://www.netlib.org/benchmark/hpl](http://www.netlib.org/benchmark/hpl)

---

## 9. Contributors

- **Kamogelo Macena** – Team Lead & Documentation
- **Mpolokeng Mpolokeng** – Benchmarking & Testing
- **Musa Mazibuko** – System Configuration & Monitoring
- **Lehlogonolo Mothibi** – Data Analysis & Reporting

---

## 10. License

This research and its associated scripts are released for academic and educational purposes under the **MIT License**.

---

## Contact

For inquiries or collaboration:

- **Email:** kamogelo.macena@202424481@spu.ac.za
- **CHPC Project:** DEVL1048
- **Team:** Debug Thugs

---

## 11. Repository Structure

```
DebugThugs-HPC-Project/
├── README.md
├── LICENSE
├── .gitignore
├── requirements.txt
├── CONTRIBUTING.md
│
├── docs/
│   ├── 01_introduction.md
│   ├── 02_cluster_setup.md
│   ├── 03_benchmarking_methodology.md
│   ├── 04_performance_analysis.md
│   ├── 05_troubleshooting.md
│   ├── 06_recommendations.md
│   ├── figures/
│   │   ├── network_topology.png
│   │   ├── workflow_diagram.png
│   │   ├── results_plot.png
│   │   └── slurm_job_flow.png
│   └── references.bib
│
├── config/
│   ├── cluster_config.yaml
│   ├── modules/
│   │   ├── openmpi_module.sh
│   │   ├── openblas_module.sh
│   │   ├── openfoam_module.sh
│   │   ├── ansys_module.sh
│   │   └── slurm_module.sh
│   ├── environment/
│   │   ├── env_setup.sh
│   │   ├── dependencies_install.sh
│   │   └── path_exports.sh
│   └── ansible/
│       ├── inventory.ini
│       ├── playbooks/
│       │   ├── install_dependencies.yml
│       │   ├── configure_slurm.yml
│       │   ├── mount_nfs.yml
│       │   ├── setup_openmpi.yml
│       │   └── benchmark_deploy.yml
│       └── roles/
│           ├── common/
│           ├── slurm/
│           ├── openmpi/
│           ├── openfoam/
│           └── fluent/
│
├── scripts/
│   ├── setup_environment.sh
│   ├── load_modules.sh
│   ├── monitor_resources.sh
│   ├── power_measurement.sh
│   ├── performance_logger.py
│   ├── parse_results.py
│   ├── visualize_results.ipynb
│   └── sync_results.sh
│
├── benchmarks/
│   ├── hpl/
│   │   ├── HPL.dat
│   │   ├── Makefile
│   │   ├── run_hpl.slurm
│   │   ├── results/
│   │   │   ├── hpl_output.log
│   │   │   └── performance_summary.txt
│   │   └── README.md
│   │
│   ├── openfoam/
│   │   ├── system/
│   │   │   ├── controlDict
│   │   │   ├── fvSchemes
│   │   │   └── fvSolution
│   │   ├── constant/
│   │   │   ├── transportProperties
│   │   │   ├── turbulenceProperties
│   │   │   └── polyMesh/
│   │   │       ├── blockMeshDict
│   │   │       └── boundary
│   │   ├── test_case/
│   │   │   ├── cavity/
│   │   │   └── pipeFlow/
│   │   ├── run_openfoam.slurm
│   │   ├── logs/
│   │   │   ├── openfoam_run.log
│   │   │   └── solver_performance.log
│   │   └── results/
│   │       ├── postProcessing/
│   │       └── velocity_profiles/
│   │
│   ├── fluent/
│   │   ├── test_case/
│   │   │   ├── heat_exchanger.cas
│   │   │   ├── heat_exchanger.dat
│   │   │   └── mesh_files/
│   │   ├── run_fluent.slurm
│   │   ├── output/
│   │   │   ├── fluent_output.log
│   │   │   ├── residuals.csv
│   │   │   └── performance_report.txt
│   │   └── results/
│   │       ├── pressure_distribution.png
│   │       ├── temperature_contours.png
│   │       └── speedup_analysis.txt
│   │
│   └── logs/
│       ├── cluster_logs/
│       │   ├── head_node.log
│       │   ├── compute_node1.log
│       │   └── compute_node2.log
│       ├── slurm_output/
│       │   ├── job_001.out
│       │   ├── job_001.err
│       │   └── scheduler_debug.log
│       └── monitoring/
│           ├── cpu_usage.csv
│           ├── memory_usage.csv
│           └── network_activity.csv
│
├── data/
│   ├── raw/
│   │   ├── input_meshes/
│   │   └── initial_conditions/
│   ├── processed/
│   │   ├── cleaned_data/
│   │   └── merged_results/
│   └── reports/
│       ├── hpl_summary.xlsx
│       ├── openfoam_performance.xlsx
│       ├── fluent_analysis.xlsx
│       └── combined_results.csv
│
├── notebooks/
│   ├── hpl_analysis.ipynb
│   ├── openfoam_postprocessing.ipynb
│   ├── fluent_analysis.ipynb
│   └── visualization.ipynb
│
├── results/
│   ├── benchmark_summary.pdf
│   ├── hpl_report.pdf
│   ├── openfoam_report.pdf
│   ├── fluent_report.pdf
│   └── comparative_analysis.pdf
│
└── reports/
    ├── project_proposal.docx
    ├── interim_report.docx
    ├── final_report.docx
    └── presentation_slides.pptxx
```

---

**End of Document**
