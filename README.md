# ear-docker

A containerised SLURM cluster for evaluating the [Energy-Aware Runtime (EAR 3.2)](https://github.com/eas4dc/EAR), developed jointly by the Barcelona Supercomputing Centre (BSC) and Lenovo.

This repository was produced during a three-month internship (September–November 2025) at the **College of Computing, Université Mohammed VI Polytechnique (UM6P)**, under the supervision of **Prof. Dr. Robert Basmadjian**, Head of the Toubkal Supercomputer.

> **⚠️ Read the [Known Limitations](#known-limitations) and [Hardware Warning](#hardware-warning) sections before running this on any machine you care about.**

---

## What This Does

EAR is an energy management framework for HPC clusters. Its node daemon (EARD) requires root access to real hardware interfaces — the `acpi-cpufreq` kernel driver for CPU frequency control and Intel RAPL for energy measurement — making simulation inside virtual machines impossible.

This repository containerises the full EAR + SLURM stack using Docker and Docker Compose, running compute containers in **privileged mode** so that EARD can access the host's actual hardware interfaces. The result is a functional simulation of an EAR-enabled cluster on a single machine, suitable for validating EAR's software stack and deployment configuration.

### What is simulated

| Container | Role |
|---|---|
| `mysql` | MariaDB 10.3.39 — persistent energy and job accounting |
| `slurmdbd` | SLURM database daemon |
| `slurmctld` | SLURM controller + login node |
| `c1`, `c2` | Compute nodes (`slurmd` + `eard` + `earl`) — run **privileged** |
| `eardbd` | EAR database buffer daemon |
| `eargm` | EAR global manager (passive monitoring mode) |

### What is not simulated

Because all containers share one physical host, RAPL energy counters reflect aggregate host consumption rather than per-node values. CPU frequency changes applied by one container's EARD affect the entire machine. This simulation is valid for **functional validation** of EAR's components and configuration, not for quantitative per-node energy measurement.

---

## Software Versions

| Software | Version |
|---|---|
| EAR | 3.2 |
| SLURM | 21.08.6-1 |
| MariaDB | 10.3.39 |
| Base OS (containers) | RockyLinux 8 |
| OpenMPI | system package (RHEL 8 era) |

---

## Prerequisites

### Host machine requirements

- **Host OS:** A Linux distribution in the RHEL 8 family is strongly recommended — **RockyLinux 8** or **AlmaLinux 8**. Using CentOS Stream 10 or another RHEL 10-era host was tested and caused MPI+SLURM integration failures (see [Known Limitations](#known-limitations)).
- **CPU:** At least 8 logical cores. CPU pinning reserves cores 1–7 for containers and core 0 for the kernel; a machine with more cores gives more flexibility (see [Notes on CPU Pinning](#notes-on-cpu-pinning)).
- **cpufreq driver:** The host must be using `acpi-cpufreq`. Modern Intel systems default to `intel_pstate`, which must be disabled before building (see [Host Configuration](#host-configuration)).
- **Docker and Docker Compose** installed.
- **munge** installed on the host (used by `build_images.sh` to generate the shared authentication key).

### Internet access

The build downloads SLURM from GitHub and EAR from GitHub. Ensure the build machine has internet access.

---

## Host Configuration

These changes must be applied to the host OS **before** building or running the cluster.

### 1. Switch the CPU scaling driver

EAR 3.2 requires `acpi-cpufreq`. Disable `intel_pstate` via the kernel command line:

```bash
# On RHEL/CentOS systems (recommended)
sudo grubby --update-kernel=ALL --args="intel_pstate=disable"
sudo reboot

# Verify after reboot
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver
# Expected output: acpi-cpufreq
```

### 2. CPU pinning (optional but recommended)

Isolate cores 1–7 for the containers, leaving core 0 for the kernel:

```bash
sudo grubby --update-kernel=ALL --args="intel_pstate=disable isolcpus=1-7"
sudo reboot
```

For runtime management with `cset`:

```bash
sudo dnf install cpuset
sudo cset shield --cpu 1-7 --kthread=on
```

> **Note:** Leave as more logical CPUs as you can for the kernel. Reserving only 1 CPU for the kernel (as was done during this internship's development) contributed to hardware instability.

---

## Build and Run

### 1. Clone the repository

```bash
git clone https://github.com/AnasOujja/ear-docker.git
cd ear-docker
```

### 2. Prepare the host and build images

`build_images.sh` creates the munge key and captures the host CPU topology (needed by the patched EAR source), then builds all Docker images:

```bash
chmod +x build_images.sh
./build_images.sh
```

> Expect 15–30 minutes on first build depending on network speed and hardware. SLURM and EAR are compiled from source.

### 3. Start the cluster

```bash
docker compose up -d
docker compose logs -f   # follow startup progress
```

### 4. Initialise the EAR database (first run only)

```bash
docker exec -it eardbd edb_create

```

This creates the `EAR_DB` schema and the `ear_db` / `ear_commands` users in MariaDB. Only needs to be run once.

---

## Verifying the Cluster

```bash
# Enter the controller
docker exec -it slurmctld bash

# Check SLURM node states — both c1 and c2 should show 'idle'
sinfo

# Check EARD is running on c1
docker exec c1 ps aux | grep eard

# Confirm acpi-cpufreq is active inside the compute container
docker exec c1 cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver
# Expected: acpi-cpufreq

# Confirm RAPL is accessible (non-zero value expected)
docker exec c1 cat /sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj

# Check EARDBD logs
docker compose logs eardbd
```

---

## Submitting Jobs

All jobs automatically load EARL because `earlib_default=on` is set in `plugstack.conf`. From inside `slurmctld`:

```bash
docker exec -it slurmctld bash

# Simple validation
srun -N 2 sleep 30

# CPU-bound bash workload (included in repo)
srun -N 2 /data/cpu-bound.sh 1000000

# Memory-bound bash workload (included in repo)
srun -N 2 /data/memory-bound.sh 512

# Query EAR accounting data for a completed job
eacct -j <jobid>
ereport -n c1
```

### MPI jobs

```bash
# Compile the included MPI test program
mpicc -o /data/mpi_test /data/mpi_test.c

# Run across both compute nodes
srun -N 2 -n 4 --mpi=pmix /data/mpi_test
```

> **⚠️ MPI through SLURM did not work during development.** See [Known Limitations](#known-limitations).

---

## EAR Source Patches

Two EAR 3.2 source files are replaced before compilation. Both required patches because EAR's original behaviour did not work correctly inside the containers, even though the paths and permissions appeared correct from manual inspection. The root cause was not identified in either case.

### `overrides/hardware_info.c`

EAR reads CPU topology from `/sys/devices/system/cpu/cpu0/topology/`. This did not function correctly inside the containers. The patch redirects reads to `/tmp/thread_siblings` and `/tmp/core_siblings`, which are bitmask files captured from the host at build time by `build_images.sh` and copied into the image.

### `overrides/energy_node.c`

EAR resolves its RAPL energy plugin path from configuration at runtime. This resolution failed inside the containers. The patch hardcodes the path to `/usr/lib/plugins/energy_rapl.so`.

---

## Notes on CPU Pinning

CPU pinning was introduced with a specific architectural goal: on a **multi-socket machine**, Intel RAPL exposes one independent Package domain per physical socket. By pinning each compute container exclusively to the CPUs of one socket and adjusting EARD's RAPL initialisation to read only that socket's energy counter, genuine per-node energy isolation could be achieved within a single host — making the simulation substantially more realistic.

Neither the development laptop nor the university workstation used during the internship were multi-socket machines, so this was never exercised. The pinning was kept in the configuration as groundwork for this future improvement. Therefore, this part an be ignored.

---

## Known Limitations

### MPI + SLURM integration does not work

Running MPI jobs through SLURM with EARL loaded via EARPLUG failed during development. The failure occurs before any application code executes. Multiple version combinations were tested (different OpenMPI releases, PMI2 vs PMIx, different SLURM minor versions, various `--mpi` and `--ear-mpi-dist` flags) — none produced a working MPI job.

The root cause was not identified. The most likely hypothesis is that running MPI through SLURM inside Docker containers requires the host OS and the container base image to share compatible system library generations, and a mismatch between them makes this unreliable regardless of which specific versions are chosen inside the container. If this is correct, using **RockyLinux 8 or AlmaLinux 8 as the host OS** — matching the container base — would be the first step to test.

As a consequence, EARL's MPI interception, DynAIS phase detection, application signature computation, and energy policy enforcement were never exercised. Only bash-script jobs were validated.

### Dummy system signature coefficients

The compute node entrypoint runs `coeffs_null` to generate zeroed-out coefficient files, bypassing the full learning phase (which requires running NAS benchmarks at every CPU P-state under EARD). Even if MPI jobs worked, EARL could not make meaningful energy projections without real coefficients. The learning phase must be completed before testing energy policies.

### Shared hardware view

All containers share the host's physical hardware. This is an inherent limitation of any single-host container simulation.

---

## Hardware Warning

> **Do not run this on a machine you cannot afford to lose.**

During development, the host laptop (Intel Core i5-1135G7) suffered progressive hardware damage over two months — frequent crashes, freezes, and eventually an ACPI Error. The likely causes were: sustained CPU P-state manipulation by EARD using the non-default `acpi-cpufreq` driver, and reserving only a single logical CPU for the kernel while aggressively isolating the rest.

This simulation should be run on a **dedicated, expendable machine**.

---

## License

The original work in this repository — Dockerfiles, entrypoint scripts, configuration files, `build_images.sh`, test workloads, and source patches — is released under the **MIT License**.

```
MIT License

Copyright (c) 2025 Anas Oujja

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Third-party software

This repository builds the following third-party software from source during the Docker image build. Their licenses govern their respective source code and binaries:

| Software | License | Source |
|---|---|---|
| EAR 3.2 | Eclipse Public License v2.0 (EPL-2.0) | https://github.com/eas4dc/EAR |
| SLURM 21.08.6 | GNU General Public License v2.0 | https://github.com/SchedMD/slurm |
| MariaDB 10.3.39 | GNU General Public License v2.0 | https://mariadb.org |
| OpenMPI | BSD 3-Clause | https://www.open-mpi.org |

The MIT License above applies **only** to the original files in this repository. It does not relicense EAR, SLURM, MariaDB, or OpenMPI. The `overrides/hardware_info.c` and `overrides/energy_node.c` files are derived from EAR source code and remain subject to the EPL-2.0.

---

## Acknowledgements

Developed at the College of Computing, Université Mohammed VI Polytechnique (UM6P), under the supervision of **Prof. Dr. Robert Basmadjian**, Head of the Toubkal Supercomputer.

EAR was developed by the Barcelona Supercomputing Centre (BSC) and Lenovo. Reference publication: J. Corbalán and L. Brochard, *"EAR: Energy management framework for supercomputers"*, SC '19 Workshops, Denver, CO, November 2019.
