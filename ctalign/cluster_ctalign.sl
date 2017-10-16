#!/bin/bash

### Input parameters #######################################################
# 1: DATA FILE: SOURCEDATA (contains the stack of images to be aligned)
# 2 ..: ctalign parameters
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es
#SBATCH -o /beamlines/bl09/controls/cluster/logs/slurm.%N.%j.out # STDOUT
#SBATCH -e /beamlines/bl09/controls/cluster/logs/slurm.%N.%j.err # STDERR
#SBATCH --tmp=8G
################################################################################

echo `date`
start=`date +%s`

### Copy files to computing nodes ##############################################
SOURCEDATA=$1
SOURCEDATADIR=$(dirname "$1")
SOURCEDATAFILE=$(basename "$1")

WORKDIR="/beegfs/scratch/bl09/bl09_ctalign_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "\nCopying input files to Cluster local disks"
echo "sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}"
sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}

### MAIN script ################################################################
echo "\n\n"
echo "Running ctalign"
echo "srun ctalign ${WORKDIR}/${SOURCEDATAFILE} ${@:2}"
srun ctalign ${WORKDIR}/${SOURCEDATAFILE} "${@:2}"

### Recovering results #########################################################
OUTPUT_FILE="${SOURCEDATAFILE%.hdf5}_ali.hdf5"
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

