#!/bin/bash

### Input parameters ###########################################################
# 1: DATA FILE: SOURCEDATA (contains the stack of images to be aligned)
# 2 ..: xrm2nexus parameters
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
SOURCEDIR=$1
WORKDIR="/tmp/bl09_xrm2nexus_${SLURM_JOBID}"
mkdir -p $WORKDIR/$SOURCEDIR

echo $'\nCopying input files to Cluster local disks'
for f in $SOURCEDIR/*.xrm ; do
    sbcast -p $f $WORKDIR/$SOURCEDIR/`basename $f`
done


### MAIN script ################################################################
OUT_HDF5_STACKS=outputhdf
mkdir -p $WORKDIR/$OUT_HDF5_STACKS
echo $'\n\n'
echo "Running xrm2nexus"
echo "srun xrm2nexus $WORKDIR/$SOURCEDIR --output-dir-name $WORKDIR/$OUT_HDF5_STACKS ${@:3}"
srun xrm2nexus $WORKDIR/$SOURCEDIR --output-dir-name $WORKDIR/$OUT_HDF5_STACKS "${@:3}"


### Recovering results #########################################################
if [ -z "$2" ]; then
    OUTDIR=$SOURCEDIR
else
    OUTDIR=$2
fi

outdirectories=(`find $WORKDIR/$OUT_HDF5_STACKS -maxdepth 1 -type d`)
outdirectories=${outdirectories[@]:1}

echo $'\n\nRecovering results:'
for outdirectory in $outdirectories; do
    echo $outdirectory
    finaloutdir=$(basename $outdirectory)
    mkdir -p $OUTDIR/$finaloutdir

    for f in $outdirectory/*; do
        echo "sgather -kpf $f $OUTDIR/$finaloutdir/`basename $f`"
        sgather -kpf $f $OUTDIR/$finaloutdir/`basename $f`
        # Fix output filename
        mv $OUTDIR/$finaloutdir/`basename $f`.`hostname` $OUTDIR/$finaloutdir/`basename $f`
    done
done


### Time spent for processing the job ##########################################
end=`date +%s`
runtime=$((end-start))
echo $'\n'
echo "Time to run: $runtime seconds"
################################################################################



