#!/bin/bash

### Input parameters #######################################################
# 1: Input: HDF5 File containing the raw data hdf5 image stack
# 2: Optional: Reconstruction SIRT Iterations (default: 30)
# 3: Optional: Reconstruction height (Default: 500)
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH --mail-user=mrosanes@cells.es 
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_hdf2recons_%N_%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_hdf2recons_%N_%j.err
#SBATCH --tmp=16G
#SBATCH -N 1
#SBATCH -c 32
################################################################################

echo `date`
start=`date +%s`

### IMPORTANT VARIABLES ########################################################
INIT_DIR=`pwd`

SOURCEDATA=$1
SOURCEDATADIR=$(dirname "$SOURCEDATA")
SOURCEDATAFILE=$(basename "$SOURCEDATA")
ANGLES="angles.tlt"

if [ -z "$2" ]; then
    ITERATIONS=30
else
    ITERATIONS=$2
fi

if [ -z "$3" ]; then
    HEIGHT=500
else
    HEIGHT=$3
fi

### Copy files to computing nodes ##############################################
WORKDIR="/tmp/bl09_hdf2recons_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "Copying input files to Cluster local disks"
echo "sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}"
sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}

### MAIN script ################################################################
cd ${WORKDIR}
echo "Running hdf2recons Workflow"
echo "---------------------------"

# Normalize raw data hdf5 image stack
normalize ${SOURCEDATAFILE}
normalized_hdf5="${SOURCEDATAFILE%.hdf5}_norm.hdf5"

# Align normalized hdf5 image stack
ctalign ${normalized_hdf5}
aligned_hdf5="${normalized_hdf5%.hdf5}_ali.hdf5"

# Convert aligned data stack from hdf5 to mrc using scipion xmipp
align_tree_hdf5="FastAligned/tomo_aligned@"${aligned_hdf5}
align_mrc="${aligned_hdf5%.hdf5}.mrc"
scipion xmipp_image_convert -i ${align_tree_hdf5} -o ${align_mrc}
sleep 2

# Reconstruct using tomo3d
echo "Running tomo3d"
align_xzy="${align_mrc%_ali.mrc}_recons.xzy"
echo "srun tomo3d -a ${ANGLES} -i ${align_mrc} -l ${ITERATIONS} -z ${HEIGHT} -S -t 32 -H -o ${align_xzy}"
srun tomo3d -a ${ANGLES} -i ${align_mrc} -l ${ITERATIONS} -z ${HEIGHT} -S -t 32 -H -o ${align_xzy}

# Flip axis to have the correct xyz coordinates in the reconstructed volume
echo "Running trimvol"
align_xyz="${align_xzy%.xzy}.xyz"
echo "srun trimvol -yz ${align_xzy} ${align_xyz}"
srun trimvol -yz ${align_xzy} ${align_xyz}
OUTPUT_FILE_xyz=${align_xyz}
OUTPUT_FILE=${align_xyz%.xyz}.mrc
cd $INIT_DIR

### Recovering results #########################################################
echo "Recovering results:"
echo "sgather -kpf ${WORKDIR}/${OUTPUT_FILE_xyz}  ${SOURCEDATADIR}/${OUTPUT_FILE}"
sgather -kpf ${WORKDIR}/${OUTPUT_FILE_xyz}  ${SOURCEDATADIR}/${OUTPUT_FILE}
################################################################################

### Fix output file name by removing the node name from the suffix #############
mv ${SOURCEDATADIR}/${OUTPUT_FILE}.`hostname` ${SOURCEDATADIR}/${OUTPUT_FILE}
################################################################################

### Time spent for processing the job ##########################################
end=`date +%s`
runtime=$((end-start))
echo "Time to run: $runtime seconds"
################################################################################


