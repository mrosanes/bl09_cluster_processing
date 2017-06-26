#!/bin/bash

## WORKFLOW: 
# - xrm2nexus
# - normalization
# - crop
# - align the images for each angle (multifocus)
# - fuse
# - deconvolve

##### Input Arguments ##########################################################
# 1: Input directory: folder containing the xrm files, 
#                     each xrm file containing a single image
# 2: output directory
# 3: Date (default: 20161201)
# 3: ZP dr (default: 25)
# 4: dx (Default: 10)
# 5: kw (Default: 0.02)
# 6: zSize (Default: 20)
# 7: psf_dir (Default: /beamlines/bl09/controls/user_resources/psf_directory)
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_xtend_deconv_%N.%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_xtend_deconv_%N.%j.err
#SBATCH --tmp=8G
################################################################################


echo `date`
start=`date +%s`

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/hpcsoftware/MATLAB/MATLAB_Runtime/v90/runtime/glnxa64:/mnt/hpcsoftware/MATLAB/MATLAB_Runtime/v90/bin/glnxa64:/mnt/hpcsoftware/MATLAB/MATLAB_Runtime/v90/sys/os/glnxa64

### Copy files to computing nodes ##############################################

SOURCEDATADIR=$1
OUTDIR=$2

if [ -z "$3" ]; then
    ZP_DR=25
else
    ZP_DR=$3
fi

if [ -z "$4" ]; then
    DX=10
else
    DX=$4
fi

if [ -z "$5" ]; then
    KW=0.02
else
    KW=$5
fi

if [ -z "$6" ]; then
    ZSIZE=20
else
    ZSIZE=$6
fi

if [ -z "$7" ]; then
    PSF_DIR="/beamlines/bl09/controls/user_resources/psf_directory"
else
    PSF_DIR=$7
fi


WORKDIR="/tmp/bl09_xtend_deconv_${SLURM_JOBID}"
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
echo "Running xtend_deconv"
echo "srun xtend_deconv ${INPUTDATACLUSTERDIR} ${OUTPUTDATACLUSTERDIR} ${ZP_DR} ${DX} ${KW} ${ZSIZE} ${PSF_DIR}"
srun xtend_deconv ${INPUTDATACLUSTERDIR} ${OUTPUTDATACLUSTERDIR} ${ZP_DR} ${DX} ${KW} ${ZSIZE} ${PSF_DIR}


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
        f_basename=$(basename "$f")
        if [[ $f_basename == *"_FS.mrc" ]] || [[ $f_basename == *"_deconv_"* ]] || [[ $f_basename == *"angles.tlt" ]]; then
            echo $f_basename
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

