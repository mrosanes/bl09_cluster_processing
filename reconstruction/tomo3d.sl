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
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_tomo3d_%N_%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_tomo3d_%N_%j.err
#SBATCH --tmp=16G
#SBATCH -N 1
#SBATCH -c 48
################################################################################

echo `date`
start=`date +%s`

### IMPORTANT VARIABLES ########################################################
INIT_DIR=`pwd`

SOURCEDATA=$1
SOURCEDATADIR=$(dirname "$SOURCEDATA")
SOURCEDATAFILE=$(basename "$SOURCEDATA")
ANGLESDATA=$2
ANGLESDIR=$(dirname "$ANGLESDATA")
ANGLES=$(basename "$ANGLESDATA")

if [ -z "$3" ]; then
    OUTPUT_FILE="${SOURCEDATAFILE%.mrc}_recons.xzy"
else
    OUTPUT_FILE=$3
fi

if [ -z "$4" ]; then
    ITERATIONS=30
else
    ITERATIONS=$4
fi

if [ -z "$5" ]; then
    HEIGHT=500
else
    HEIGHT=$5
fi

### Copy files to computing nodes ##############################################
WORKDIR="/tmp/bl09_tomo3d_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "Copying input files to Cluster local disks"
echo "sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}"
sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}
echo "sbcast ${SOURCEDATADIR}/${ANGLES} ${WORKDIR}/${ANGLES}"
sbcast ${SOURCEDATADIR}/${ANGLES} ${WORKDIR}/${ANGLES}

### MAIN script ################################################################
cd ${WORKDIR}
echo "Running tomo3d"
echo "srun tomo3d -a ${ANGLES} -i ${SOURCEDATAFILE} -l ${ITERATIONS} -z 500 -S -t 48 -H -o ${OUTPUT_FILE}"
srun tomo3d -a ${ANGLES} -i ${SOURCEDATAFILE} -l ${ITERATIONS} -z 500 -S -t 48 -H -o ${OUTPUT_FILE}
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


