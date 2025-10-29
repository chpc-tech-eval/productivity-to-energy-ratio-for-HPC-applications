# Project Overview

**Goal:** Determine how to operate repurposed legacy HPC hardware in the most energy-efficient way for different applications.<br/>
**Duration:** 6 weeks<br/>
**Team members:**<br/>
Anand Patel(Mentor)<br/>
Sune Torien(Captain)<br/>
Mubeen Dewan<br/>
Ntandoyenkosi Memela<br/>
Vele Nefale<br/>

## Project Repo layout

    ├── data/ # Raw and processed benchmark data
    │ ├── raw/ # Raw power/time logs from tests
    │ └── processed/ # Cleaned and formatted CSV data
    │
    ├── scripts/ # Benchmarking and analysis scripts
    │ ├── setup/ # Installation and configuration scripts
    │ │ ├── install_wrf.sh
    │ │ ├── install_su2.sh
    │ │ └── setup_environment.sh
    │ │
    │ ├── benchmarks/ # Scripts for running test cases
    │ │ ├── run_wrf_benchmarks.sh
    │ │ ├── run_su2_benchmarks.sh
    │ │ └── batch_job_template.slurm
    │ │
    │ ├── power_monitoring/ # Power measurement utilities
    │ │ ├── read_rapl.py
    │ │ ├── log_power_usage.sh
    │ │ └── analyze_power_data.py
    │ │
    │ └── analysis/ # Data analysis and plotting scripts
    │ ├── process_results.py
    │ ├── plot_energy_vs_perf.ipynb
    │ └── summary_statistics.py
    │
    ├── benchmarks/ # Benchmark input and output directories
    │ ├── wrf/
    │ │ ├── test_case_1/
    │ │ └── test_case_2/
    │ └── su2/
    │ ├── test_case_1/
    │ └── test_case_2/
    │
    └── presentation/ # Project presentation materials
    │ ├── slides.pptx
    │ └── figures/
    │
    ├── mkdocs.yml    # The mkdocs configuration file.
    ├── docs/
    │ ├── index.md  # The documentation homepage.
    │ └── ...       # Other markdown pages and other files.
