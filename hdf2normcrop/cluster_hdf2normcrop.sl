#!/bin/bash

### Input parameters ###########################################################
# 1: DATA FILE: SOURCEDATA (contains the hdf5 stack of images to norm and crop)
# 2 ..: hdf2normcrop parameters
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_hdf2normcrop_%N.%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_hdf2normcrop_%N.%j.err
#SBATCH --tmp=8G
################################################################################

echo `date`
start=`date +%s`

### Copy files to computing nodes ##############################################
SOURCEDATA=$1
SOURCEDATADIR=$(dirname "$1")
SOURCEDATAFILE=$(basename "$1")

WORKDIR="/beegfs/scratch/bl09/bl09_hdf2normcrop_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "Copying input files to Cluster local disks"
echo "sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}"
sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}

### MAIN script ################################################################
echo "Running hdf2normcrop"
echo "srun hdf2normcrop ${WORKDIR}/${SOURCEDATAFILE} ${@:2}"
srun hdf2normcrop ${WORKDIR}/${SOURCEDATAFILE} "${@:2}"

### Recovering results #########################################################
OUTPUT_FILE="${SOURCEDATAFILE%.*}_norm_crop.hdf5"
echo "Recovering results:"
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
echo "Time to run: $runtime seconds"
################################################################################

