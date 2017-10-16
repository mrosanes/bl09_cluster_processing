#!/bin/bash

### Input arguments ############################################################
# 1: DATA FILES: txrm stack of data images and txrm stack of FF images.
# 2 ..: txrm2norm parameters
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_txrm2norm_%N.%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_txrm2norm_%N.%j.err
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

WORKDIR="/beegfs/scratch/bl09/bl09_txrm2norm_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "Copying input files to Cluster local disks"
echo "sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}"
echo "sbcast ${SOURCEDATA_FF} ${WORKDIR}/${SOURCEDATAFILE_FF}"
sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}
sbcast ${SOURCEDATA_FF} ${WORKDIR}/${SOURCEDATAFILE_FF}

### MAIN script ################################################################
echo "Running txrm2norm"
echo "srun txrm2norm ${WORKDIR}/${SOURCEDATAFILE} ${WORKDIR}/${SOURCEDATAFILE_FF} ${@:3}"
srun txrm2norm ${WORKDIR}/${SOURCEDATAFILE} ${WORKDIR}/${SOURCEDATAFILE_FF} "${@:3}"

### Recovering results #########################################################
OUTPUT_FILE="${SOURCEDATAFILE%.*}_norm.hdf5"
echo "Recovering results:"
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

