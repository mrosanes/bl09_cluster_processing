#!/bin/bash

### Input parameters #######################################################
# 1: DATA FILE: SOURCEDATA (bl09 normalized hdf5 file)
# 2 ..: extract_angle parameters
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_extract_angle_%N.%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_extract_angle_%N.%j.err
#SBATCH --tmp=8G
################################################################################

echo `date`
start=`date +%s`

### Copy files to computing nodes ##############################################
SOURCEDATA=$1
SOURCEDATADIR=$(dirname "$1")
SOURCEDATAFILE=$(basename "$1")

INITIAL_DIR=`pwd`

WORKDIR="/tmp/bl09_extract_angle_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "Copying input files to Cluster local disks"
echo "sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}"
sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}

### MAIN script ################################################################
echo "Running extract_angle"
cd $WORKDIR
echo "srun extract_angle ${SOURCEDATAFILE}"
srun extract_angle ${SOURCEDATAFILE}

### Recovering results #########################################################
OUTPUT_FILE="angles.tlt"
echo "Recovering results:"
echo "sgather -kpf ${OUTPUT_FILE}  ${INITIAL_DIR}/${OUTPUT_FILE}"
sgather -kpf ${OUTPUT_FILE}  ${INITIAL_DIR}/${OUTPUT_FILE}
################################################################################

### Fix output file name by removing the node name from the suffix #############
cd $INITIAL_DIR
mv ${OUTPUT_FILE}.`hostname` ${OUTPUT_FILE}
################################################################################

### Time spent for processing the job ##########################################
end=`date +%s`
runtime=$((end-start))
echo "Time to run: $runtime seconds"
################################################################################

