#!/bin/bash

#SBATCH -p short # partition (queue) (it can be short, general, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es 
#SBATCH -o /beamlines/bl09/controls/cluster/logs/slurm.%N.%j.out # STDOUT
#SBATCH -e /beamlines/bl09/controls/cluster/logs/slurm.%N.%j.err # STDERR

echo "Running xrm2nexus.sl on Cluster nodes"
srun xrm2nexus $*




