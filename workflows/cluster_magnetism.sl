#!/bin/bash

### Input parameters ###########################################################
# 1: Input: txt file containing the collect script
# (be located in the xrm input files folder before executing magnetism)
# 2 ..: magnetism parameters
################################################################################

### SLURM environment ##########################################################
#SBATCH -p medium # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es 
#SBATCH -o /beamlines/bl09/controls/cluster/logs/magnetism_logs/bl09_magnetism_%N_%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/magnetism_logs/bl09_magnetism_%N_%j.err
#SBATCH --mem=32G
#SBATCH --tmp=300G
################################################################################

echo `date`
start=`date +%s`

### Copy files to computing nodes ##############################################
SOURCEDATADIR=`pwd`
SOURCEDATAFILE=$1

#WORKDIR="/beegfs/scratch/bl09/bl09_magnaltre"
WORKDIR="/beegfs/scratch/bl09/bl09_magnetism_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "---"
echo "Copying input files to Cluster local disks"
sbcast ${SOURCEDATAFILE} ${WORKDIR}/${SOURCEDATAFILE}

for file in ${SOURCEDATADIR}/*.xrm; do
    basefile=$(basename $file)
    echo "sbcast ${file} ${WORKDIR}/${basefile}"
    sbcast ${file} ${WORKDIR}/${basefile}
done


### MAIN script ################################################################
echo "\n\n"
echo "Running magnetism"
cd ${WORKDIR}
echo "srun magnetism ${WORKDIR}/${SOURCEDATAFILE} --db --ff --th --stack"
srun magnetism ${WORKDIR}/${SOURCEDATAFILE} --db --ff --th --stack
### Recovering results #########################################################

### Recovering results #########################################################
ls *FS.hdf5
echo "Recovering results:"

ls *FS.hdf5
for file in ${WORKDIR}/*FS.hdf5; do
    basefile=$(basename $file)
    echo "sgather -kpf ${file} ${SOURCEDATADIR}/${basefile}"
    sgather -kpf ${file} ${SOURCEDATADIR}/${basefile}
done
################################################################################


### Fix output file name by removing the node name from the suffix #############
cd ${SOURCEDATADIR}
for file in *.`hostname`; do
    mv $file ${file%.`hostname`}
done
################################################################################


### Time spent for processing the job ##########################################
end=`date +%s`
runtime=$((end-start))
echo "Time to run: $runtime seconds"
################################################################################




