#!/bin/bash

### Input parameters #######################################################
# 1: Input mrc file containing the projections
# 2: Input tilt angles file 
# 3: Optional: Output file name.
# 4: Optional: Iterations (default: 30)
# 5: Optional: height (Default: 500)
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH --mail-user=mrosanes@cells.es 
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_trimvol_%N_%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_trimvol_%N_%j.err
#SBATCH --tmp=16G
#SBATCH -N 1
################################################################################

echo `date`
start=`date +%s`

### IMPORTANT VARIABLES ########################################################
INIT_DIR=`pwd`

SOURCEDATA=$1
SOURCEDATADIR=$(dirname "$SOURCEDATA")
SOURCEDATAFILE=$(basename "$SOURCEDATA")

if [ -z "$2" ]; then
    OUTPUTDATA="${SOURCEDATAFILE%.xzy}.xyz"
else
    OUTPUTDATA=$2
fi
OUTPUTDATADIR=$(dirname "$OUTPUTDATA")
OUTPUT_FILE=$(basename "$OUTPUTDATA")

### Copy files to computing nodes ##############################################
WORKDIR="/tmp/bl09_trimvol_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "Copying input files to Cluster local disks"
echo "sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}"
sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}

### MAIN script ################################################################
cd ${WORKDIR}
echo "Running trimvol"
echo "srun trimvol -yz ${SOURCEDATAFILE} ${OUTPUT_FILE}"
srun trimvol -yz ${SOURCEDATAFILE} ${OUTPUT_FILE}
cd $INIT_DIR

### Recovering results #########################################################
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


