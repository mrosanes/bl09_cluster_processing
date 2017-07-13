#!/bin/bash

### Input parameters #######################################################
# 1: Input mrc file containing the projections
# 2: Input tilt angles file 
# 3: Optional: Iterations (default: 30)
# 4: Optional: height (Default: 500)
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH --mail-user=mrosanes@cells.es 
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_ali2recons_%N_%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_ali2recons_%N_%j.err
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

if [ -z "$2" ]; then
    ANGLES="angles.tlt"
else
    ANGLES=$2
    ANGLES=$(basename "$ANGLES")
fi

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
WORKDIR="/tmp/bl09_ali2recons_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "Copying input files to Cluster local disks"
echo "sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}"
sbcast ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}
echo "sbcast ${SOURCEDATADIR}/${ANGLES} ${WORKDIR}/${ANGLES}"
sbcast ${SOURCEDATADIR}/${ANGLES} ${WORKDIR}/${ANGLES}

### MAIN script ################################################################
cd ${WORKDIR}
echo "Running ali2recons Workflow"
echo "---------------------------"

# Convert aligned data stack from hdf5 to mrc using scipion xmipp
align_tree_hdf5="FastAligned/tomo_aligned@"${SOURCEDATAFILE}
align_mrc="${SOURCEDATAFILE%.hdf5}.mrc"
scipion xmipp_image_convert -i ${align_tree_hdf5} -o ${align_mrc}
sleep 2

# Reconstruct using tomo3d
echo "Running tomo3d"
align_xzy="${align_mrc%_ali.mrc}_recons.xzy"
echo "srun tomo3d -a ${ANGLES} -i ${align_mrc} -l ${ITERATIONS} -z ${HEIGHT} -S -t 48 -H -o ${align_xzy}"
srun tomo3d -a ${ANGLES} -i ${align_mrc} -l ${ITERATIONS} -z ${HEIGHT} -S -t 48 -H -o ${align_xzy}

# Flip axis to have the correct xyz coordinates in the reconstructed volume
echo "Running trimvol"
align_xyz="${align_xzy%.xzy}.xyz"
echo "srun trimvol -yz ${align_xzy} ${align_xyz}"
srun trimvol -yz ${align_xzy} ${align_xyz}
OUTPUT_FILE=${align_xyz}
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


