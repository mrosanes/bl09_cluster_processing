#!/bin/bash

### Input parameters #######################################################
# 1: Input: TXRM File containing the raw data TXRM image stack
# 2: Input: TXRM File containing the the FF TXRM image stack
# 3: Optional: SIRT Iterations used for reconstruction with tomo3d (default: 30)
# 4: Optional: height used for reconstruction with tomo3d (Default: 500)
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH --mail-user=mrosanes@cells.es 
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_txrm2recons_%N_%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_txrm2recons_%N_%j.err
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

SOURCEDATA_FF=$2
SOURCEDATADIR_FF=$(dirname "$SOURCEDATA_FF")
SOURCEDATAFILE_FF=$(basename "$SOURCEDATA_FF")

ANGLES="angles.tlt"

if [ -z "$3" ]; then
    ITERATIONS=30
else
    ITERATIONS=$3
fi

if [ -z "$4" ]; then
    HEIGHT=500
else
    HEIGHT=$4
fi

### Copy files to computing nodes ##############################################
WORKDIR="/tmp/bl09_txrm2recons_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "Copying input files to Cluster local disks"
echo "sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}"
sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}
echo "sbcast ${SOURCEDATA_FF} ${WORKDIR}/${SOURCEDATAFILE_FF}"
sbcast ${SOURCEDATA_FF} ${WORKDIR}/${SOURCEDATAFILE_FF}

### MAIN script ################################################################
cd ${WORKDIR}
echo "Running txrm2recons Workflow"
echo "---------------------------"

# Raw data stack conversion from txrm to hdf5
txrm2nexus ${SOURCEDATAFILE} ${SOURCEDATAFILE_FF} -o=sb
data_hdf5="${SOURCEDATAFILE%.txrm}.hdf5"

# Normalize raw data hdf5 image stack
normalize ${data_hdf5}
normalized_hdf5="${data_hdf5%.hdf5}_norm.hdf5"

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
align_xzy="${align_mrc%_norm_ali.mrc}_recons.xzy"
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


