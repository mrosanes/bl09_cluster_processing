#!/bin/bash

################################################################################
# 1: Input Arguments: folder containing the xrm files, 
#                     each xrm file containing a single image
# 2: Execution: xtend_1 input_folder output_folder
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

SOURCEDATADIR=$1
OUTDIR=$2

WORKDIR="/tmp/bl09_xtend_1_${SLURM_JOBID}"
INPUTDATACLUSTERDIR=$WORKDIR/inputdata
OUTPUTDATACLUSTERDIR="${WORKDIR}/output"

mkdir -p $INPUTDATACLUSTERDIR
mkdir -p $OUTPUTDATACLUSTERDIR

echo "Copying input files to Cluster local disks"
echo "sbcast from ${SOURCEDATADIR} to ${INPUTDATACLUSTERDIR}"
for f in $SOURCEDATADIR/*; do
    SOURCEDATAFILE=$(basename $f)
    echo "sbcast -p ${f} ${INPUTDATACLUSTERDIR}/${SOURCEDATAFILE}"
    sbcast -p ${f} ${INPUTDATACLUSTERDIR}/${SOURCEDATAFILE}
done


### MAIN script ################################################################
echo "Running xtend_1"
echo "srun xtend_1 ${INPUTDATACLUSTERDIR} ${OUTPUTDATACLUSTERDIR}"
srun xtend_1 ${INPUTDATACLUSTERDIR} ${OUTPUTDATACLUSTERDIR}


### Recovering results #########################################################
#### GATHER OUTPUT FILES BY PATTERN AND REPLICATE STRUCTURE OF DIRECTORIES #####
echo "Recovering results:"
echo "Output directory: $OUTDIR"
mkdir -p $OUTDIR

cluster_output_subdirs=`find $OUTPUTDATACLUSTERDIR -maxdepth 2 -type d`
c=0
for subdir in $cluster_output_subdirs; do
    echo $subdir
    if [ $c = 0 ]; then
        first_path=$subdir
    fi
    
    # Create directory structure
    sub_path="${subdir#"$first_path"}"
    output_path=$OUTDIR/$sub_path
    mkdir -p $output_path

    # Get the Fused files: averaged mrc files using many focuses (ZP positions)
    # And get also the angles.tlt files
    for f in $subdir/*; do
        if [ $f != ${f%_FS.mrc} ] || [ "$f" = "$subdir/angles.tlt" ]; then
            echo $f
            f_basename=$(basename "$f")
            echo "sgather -kpf $f $output_path/$f_basename"
            sgather -kpf $f $output_path/$f_basename
            mv $output_path/$f_basename.`hostname` $output_path/$f_basename
        fi
    done

    c=1
done

################################################################################


### Time spent for processing the job ##########################################
end=`date +%s`
runtime=$((end-start))
echo "Time to run: $runtime seconds"
################################################################################

