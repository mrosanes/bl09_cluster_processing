#!/bin/bash

################################################################################
# 1: Input Arguments: xrm files, each of them containing a single image
# 2: Execution: xtend_1 arguments
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_xtend_1_%N.%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_xtend_1_%N.%j.err
#SBATCH --tmp=8G
################################################################################

echo `date`
start=`date +%s`

### Copy files to computing nodes ##############################################
INIT_DIR=`pwd`

SOURCEDATADIR=$1
WORKDIR="/tmp/bl09_xtend_1_${SLURM_JOBID}"
INPUTDATACLUSTERDIR=$WORKDIR/inputdata
mkdir -p $WORKDIR
mkdir -p $INPUTDATACLUSTERDIR

echo "Copying input files to Cluster local disks"
echo "sbcast from ${SOURCEDATADIR} to ${INPUTDATACLUSTERDIR}"
FILES=/path/to/*
for f in $SOURCEDATADIR/*; do
    SOURCEDATAFILE=$(basename $f)
    echo "sbcast -p ${f} ${INPUTDATACLUSTERDIR}/${SOURCEDATAFILE}"
    sbcast -p ${f} ${INPUTDATACLUSTERDIR}/${SOURCEDATAFILE}
done

### MAIN script ################################################################
CLUSTER_LOCAL_OUTPUT_DIR="${WORKDIR}/output"
echo "Running xtend_1"
echo "srun xtend_1 ${INPUTDATACLUSTERDIR} ${CLUSTER_LOCAL_OUTPUT_DIR}"
srun xtend_1 ${INPUTDATACLUSTERDIR} ${CLUSTER_LOCAL_OUTPUT_DIR}

### Recovering results #########################################################

#OUTPUTDIR=$2
#OUTPUT_FILE=$(basename "`ls ${WORKDIR}/*/*/*_FS.mrc`")
#ANGLES="angles.tlt"
echo "Recovering results:"
#echo "sgather -kpf ${WORKDIR}/${OUTPUT_FILE} ${OUTPUTDIR}/${OUTPUT_FILE}"
#echo "sgather -kpf ${WORKDIR}/${ANGLES} ${OUTPUTDIR}/${ANGLES}"
#sgather -kpf ${WORKDIR}/${OUTPUT_FILE} ${OUTPUTDIR}/${OUTPUT_FILE}
#sgather -kpf ${WORKDIR}/${ANGLES} ${OUTPUTDIR}/${ANGLES}

### Fix output file name by removing the node name from the suffix #############
#mv ${SOURCEDATADIR}/${OUTPUT_FILE}.`hostname` ${SOURCEDATADIR}/${OUTPUT_FILE}
#mv ${SOURCEDATADIR}/${ANGLES}.`hostname` ${SOURCEDATADIR}/${ANGLES}

cd $INIT_DIR

### Time spent for processing the job ##########################################
end=`date +%s`
runtime=$((end-start))
echo "Time to run: $runtime seconds"
################################################################################

