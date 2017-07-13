#!/bin/bash

### Input arguments ############################################################
# 1: DATA FILES: txrm stack of data images and txrm stack of FF images.
# 2 ..: txrm2normcrop parameters
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_txrm2normcrop_%N.%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_txrm2normcrop_%N.%j.err
#SBATCH --tmp=8G
################################################################################

echo `date`
start=`date +%s`

### Copy files to computing nodes ##############################################
SOURCEDATA=$1
SOURCEDATA_FF=$2

SOURCEDATADIR=$(dirname "$SOURCEDATA")
SOURCEDATAFILE=$(basename "$SOURCEDATA")

SOURCEDATADIR_FF=$(dirname "$SOURCEDATA_FF")
SOURCEDATAFILE_FF=$(basename "$SOURCEDATA_FF")

INIT_DIR=`pwd`
WORKDIR="/tmp/bl09_txrm2normcrop_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "Copying input files to Cluster local disks"
echo "sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}"
echo "sbcast ${SOURCEDATA_FF} ${WORKDIR}/${SOURCEDATAFILE_FF}"
sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}
sbcast ${SOURCEDATA_FF} ${WORKDIR}/${SOURCEDATAFILE_FF}

### MAIN script ################################################################
echo "Running txrm2normcrop"
cd $WORKDIR
echo "srun txrm2normcrop ${SOURCEDATAFILE} ${SOURCEDATAFILE_FF} ${@:3}"
srun txrm2normcrop ${SOURCEDATAFILE} ${SOURCEDATAFILE_FF} "${@:3}"

### Recovering results #########################################################
OUTPUT_FILE="${SOURCEDATAFILE%.*}_norm_crop.hdf5"
echo "Recovering results:"
cd $INIT_DIR
echo "sgather -kpf ${WORKDIR}/${OUTPUT_FILE}  ${SOURCEDATADIR}/${OUTPUT_FILE}"
sgather -kpf ${WORKDIR}/${OUTPUT_FILE}  ${SOURCEDATADIR}/${OUTPUT_FILE}
################################################################################

### Fix output file name by removing the node name from the suffix #############
mv ${SOURCEDATADIR}/${OUTPUT_FILE}.`hostname` ${SOURCEDATADIR}/${OUTPUT_FILE}
################################################################################

### Time spent for processing the job ##########################################
end=`date +%s`
runtime=$((end-start))
echo "Time to run: $runtime seconds"
################################################################################
