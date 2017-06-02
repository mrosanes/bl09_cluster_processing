#!/bin/bash

### Input parameters ###########################################################
# 1: DATA FILE: SOURCEFOLDER (contains the folder storing the images to be fused)
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es 
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_fusionmrc_%N.%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_fusionmrc_%N.%j.err
#SBATCH --tmp=8G
################################################################################

echo `date`
start=`date +%s`

### Copy files to computing nodes ##############################################
SOURCEDATADIR="$1"
if [ -z "$1" ]; then
    SOURCEDATADIR="./"
fi

WORKDIR="/tmp/bl09_fusionmrc_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "---"
echo "Copying input files to Cluster local disks"
for file in ${SOURCEDATADIR}/*.mrc; do
    echo "sbcast ${file} ${WORKDIR}/${file}"
    sbcast ${file} ${WORKDIR}/${file}
done

### MAIN script ################################################################
echo "---"
echo "Running fusionmrc"
echo "srun fusionmrc ${WORKDIR}"
srun fusionmrc ${WORKDIR}

### Recovering results #########################################################
echo "---"
echo "Recovering results:"
OUTPUT_FILE=`find ${WORKDIR} -name "*_AVG_*"`
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
echo "---"
echo "Time to run: $runtime seconds"
################################################################################
