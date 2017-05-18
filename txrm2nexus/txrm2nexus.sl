#!/bin/bash


################################################################################
## txrm2nexus SLURM script for Cluster execution
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
SOURCEDATA_TXRM=$1
SOURCEDATA_TXRM_DIR=$(dirname "$1")
SOURCEDATA_TXRM_FILE=$(basename "$1")

SOURCEDATA_TXRM_FF=$2
SOURCEDATA_TXRM_FF_DIR=$(dirname "$2")
SOURCEDATA_TXRM_FF_FILE=$(basename "$2")

WORKDIR="/tmp/bl09_txrm2nexus_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo $'\nCopying input files to Cluster local disks'
echo "sbcast ${SOURCEDATA_TXRM} ${WORKDIR}/${SOURCEDATA_TXRM_FILE}"
sbcast ${SOURCEDATA_TXRM} ${WORKDIR}/${SOURCEDATA_TXRM_FILE}
echo "sbcast ${SOURCEDATA_TXRM_FF} ${WORKDIR}/${SOURCEDATA_TXRM_FF_FILE}"
sbcast ${SOURCEDATA_TXRM_FF} ${WORKDIR}/${SOURCEDATA_TXRM_FF_FILE}

### MAIN script ################################################################
echo $'\n\n'
echo "Running txrm2nexus"
echo "srun txrm2nexus ${WORKDIR}/${SOURCEDATA_TXRM_FILE} ${WORKDIR}/${SOURCEDATA_TXRM_FF_FILE} ${@:3}"
srun txrm2nexus ${WORKDIR}/${SOURCEDATA_TXRM_FILE} ${WORKDIR}/${SOURCEDATA_TXRM_FF_FILE} "${@:3}"

### Recovering results #########################################################
OUTPUT_FILE=`find ${WORKDIR} -type f -name '*.hdf5'`
echo $'\n\nRecovering results:'
OUT_FILE_NAME=$(basename $OUTPUT_FILE)
echo "sgather -kpf $OUTPUT_FILE  $SOURCEDATA_TXRM_DIR/$OUT_FILE_NAME"
sgather -kpf $OUTPUT_FILE $SOURCEDATA_TXRM_DIR/$OUT_FILE_NAME
################################################################################

### Fix output file name by removing the node name from the suffix #############
mv $SOURCEDATA_TXRM_DIR/$OUT_FILE_NAME.`hostname` $SOURCEDATA_TXRM_DIR/$OUT_FILE_NAME
################################################################################

### Time spent for processing the job ##########################################
end=`date +%s`
runtime=$((end-start))
echo $'\n'
echo "Time to run: $runtime seconds"
################################################################################
