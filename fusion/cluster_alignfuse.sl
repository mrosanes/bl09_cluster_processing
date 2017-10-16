#!/bin/bash

### Input parameters ###########################################################
# No Input Required 
# (be located in the mrc input files folder before executing alignfuse)
################################################################################

### SLURM environment ##########################################################
#SBATCH -p medium # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es 
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_alignfuse_%N_%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_alignfuse_%N_%j.err
#SBATCH --mem=32G
#SBATCH --tmp=300G
################################################################################

echo `date`
start=`date +%s`

### Copy files to computing nodes ##############################################
SOURCEDATADIR=`pwd`
WORKDIR="/beegfs/scratch/bl09/bl09_alignfuse_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "---"
echo "Copying input files to Cluster local disks"
for file in ${SOURCEDATADIR}/*.mrc; do
    basefile=$(basename $file)
    echo "sbcast ${file} ${WORKDIR}/${basefile}"
    sbcast ${file} ${WORKDIR}/${basefile}
done

### MAIN script ################################################################
echo "---"
echo "Running alignfuse:"
cd $WORKDIR
echo "srun alignfuse"
srun alignfuse

### Recovering results #########################################################
echo "---"
echo "Recovering results:"
OUTPUT_FILE=`find . -name "*_FS.mrc"`
echo "sgather -kpf ${OUTPUT_FILE}  ${SOURCEDATADIR}/${OUTPUT_FILE}"
sgather -kpf ${OUTPUT_FILE}  ${SOURCEDATADIR}/${OUTPUT_FILE}
### Fix output file name by removing the node name from the suffix #############
mv ${SOURCEDATADIR}/${OUTPUT_FILE}.`hostname` ${SOURCEDATADIR}/${OUTPUT_FILE}
################################################################################

### Time spent for processing the job ##########################################
end=`date +%s`
runtime=$((end-start))
echo "---"
echo "Time to run: $runtime seconds"
################################################################################


