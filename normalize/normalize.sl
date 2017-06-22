#!/bin/bash

### Input parameters #######################################################
# 1: DATA FILE: SOURCEDATA (contains the stack of images to be normalized)
# 2 ..: normalize parameters
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es 
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_normalize_%N_%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_normalize_%N_%j.err
#SBATCH --tmp=8G
################################################################################

echo `date`
start=`date +%s`

### Copy files to computing nodes ##############################################
SOURCEDATA=$1
SOURCEDATADIR=$(dirname "$1")
SOURCEDATAFILE=$(basename "$1")

WORKDIR="/tmp/bl09_normalize_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "\nCopying input files to Cluster local disks"
echo "sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}"
sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}

### MAIN script ################################################################
echo "\n\n"
echo "Running normalize"
echo "srun normalize ${WORKDIR}/${SOURCEDATAFILE} ${@:2}"
srun normalize ${WORKDIR}/${SOURCEDATAFILE} "${@:2}"

### Recovering results #########################################################
OUTPUT_FILE="${SOURCEDATAFILE%.hdf5}_norm.hdf5"
echo "\n\nRecovering results:"
echo "sgather -kpf ${WORKDIR}/${OUTPUT_FILE}  ${SOURCEDATADIR}/${OUTPUT_FILE}"
sgather -kpf ${WORKDIR}/${OUTPUT_FILE}  ${SOURCEDATADIR}/${OUTPUT_FILE}
################################################################################

### Fix output file name by removing the node name from the suffix #############
filename="$1/$2"
mv ${SOURCEDATADIR}/${OUTPUT_FILE}.`hostname` ${SOURCEDATADIR}/${OUTPUT_FILE}
################################################################################

### Time spent for processing the job ##########################################
end=`date +%s`
runtime=$((end-start))
echo "\n"
echo "Time to run: $runtime seconds"
################################################################################
