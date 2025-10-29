#  Hardware Access and Familiarization

# Accessing the Cluster
To access the HPC cluster, use SSH to connect to the login node:

```
ssh username@lengau.chpc.ac.za
```
Then access the cluster using SSH:

```
ssh username@10.128.23.187 
```


# Cluster Specs

<ul>
  <li>Nodes: 3 x Intel(R) Xeon(R) CPU E5-2680(2.70GHz)</li>
  <li>Ram: 27 GB + 14 GB swap per node</li>
  <li>Disk: 232.9 GB (Logical Volume:/home 148.1 GB)</li>
  <li>OS: Rocky Linux 8.10</li>
</ul>

# Software Installed

<ul>
  <li>Job Scheduler: Slurm Workload Manager</li>
  <li>Package Manager: Lmod</li>
  <li>Compilers: GCC 12.4.0, ...</li>
  <li>MPI: OpenMPI 4.1.6</li>
</ul>

# Cluster Usage
To submit jobs to the cluster, create a SLURM job script and use the `sbatch` command:

```
sbatch job_script.sh
```

Monitor your jobs with `squeue`:

```
squeue -u username
``` 
Cancel jobs with `scancel`:

```
scancel job_id
``` 
## Test run
A simple test run can be performed using the following SLURM script:

```bash
#!/bin/bash
#SBATCH --job-name=test
#SBATCH --nodes=3
#SBATCH --ntasks=16

echo "Job started at $(date)"
srun hostname
echo "Job ended at $(date)"
```
Then save it as `test.sh` and submit it with:

```
sbatch test.sh
```
