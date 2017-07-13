#!/bin/bash

### Input parameters ###########################################################
# Workflow for processing acquisitions with many images per each angle
# 1: Number of images per each angle 
# 2: Input Data Directory: containing xrm files each one with a single image.
# 3: Output directory
################################################################################

### SLURM environment ##########################################################
#SBATCH -p medium # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_xrm2alignfuse_manyimgperangle_%N_%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_xrm2alignfuse_manyimgperangle_%N_%j.err
#SBATCH --tmp=350G
#SBATCH --mem=16G
################################################################################


echo `date`
start=`date +%s`

# Input Arguments
NUMIMG=$1
SOURCEDIR=$2
OUTDIR=$3

root_path=`pwd`

### Copy files to computing nodes ##############################################

WORKDIR="/tmp/bl09_xrm2alignfuse_manyimgperangle_${SLURM_JOBID}"
mkdir -p $WORKDIR/$SOURCEDIR

echo $'\nCopying input files to Cluster local disks'
for f in $SOURCEDIR/*.xrm ; do
    sbcast -p $f $WORKDIR/$SOURCEDIR/`basename $f`
done

### MAIN script ################################################################

cd $WORKDIR

echo "Running xrm2alignfuse_manyimgperangle"
echo "srun xrm2alignfuse_manyimgperangle $NUMIMG $WORKDIR/$SOURCEDIR $WORKDIR/$OUTDIR"
srun xrm2alignfuse_manyimgperangle $NUMIMG $SOURCEDIR $OUTDIR 


### Recovering results #########################################################

echo "---"
echo "Recovering results:"
cd "$WORKDIR/$OUTDIR/hdf_mrc_dir/mrcnorm"
OUTPUT_FILE=`find . -name "*_FS.mrc"`
OUTPUT_FILE=$(basename "$OUTPUT_FILE")
OUT_FOLDER=$root_path/$OUTDIR
mkdir -p $OUT_FOLDER
echo "sgather -kpf ${OUTPUT_FILE}  $OUT_FOLDER/${OUTPUT_FILE}"
sgather -kpf ${OUTPUT_FILE}  ${OUT_FOLDER}/${OUTPUT_FILE}
################################################################################

### Fix output file name by removing the node name from the suffix #############
mv ${OUT_FOLDER}/${OUTPUT_FILE}.`hostname` ${OUT_FOLDER}/${OUTPUT_FILE}
################################################################################


### Time spent for processing the job ##########################################
end=`date +%s`
runtime=$((end-start))
echo $'\n'
echo "Time to run: $runtime seconds"
################################################################################



