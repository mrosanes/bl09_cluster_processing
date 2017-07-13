#!/bin/bash

### Input parameters ###########################################################
# 1: ZP dr (default: 25)
# 2: Energy (Default: 520)
# 3: Date (default: 20161201)
# 4: Input MRC File with the stack of images to be deconvolved
# 5: dx (Default: 10)
# 6: kw (Default: 0.02)
# 7: zSize (Default: 20)
# 8: psf_dir (Default: /beamlines/bl09/controls/user_resources/psf_directory)
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH --mail-user=mrosanes@cells.es 
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_tomo_deconv_wiener_%N_%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_tomo_deconv_wiener_%N_%j.err
#SBATCH --tmp=8G
#SBATCH -N 1
################################################################################

echo `date`
start=`date +%s`

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/hpcsoftware/MATLAB/MATLAB_Runtime/v90/runtime/glnxa64:/mnt/hpcsoftware/MATLAB/MATLAB_Runtime/v90/bin/glnxa64:/mnt/hpcsoftware/MATLAB/MATLAB_Runtime/v90/sys/os/glnxa64

### IMPORTANT VARIABLES ########################################################
INIT_DIR=`pwd`

if [ -z "$1" ]; then
    ZP_DR=25
else
    ZP_DR=$1
fi

if [ -z "$2" ]; then
    ENERGY=520
else
    ENERGY=$2
fi

if [ -z "$3" ]; then
    DATE=20161201
else
    DATE=$3
fi

if [ -z "$5" ]; then
    DX=10
else
    DX=$5
fi

if [ -z "$6" ]; then
    KW=0.02
else
    KW=$6
fi

if [ -z "$7" ]; then
    ZSIZE=20
else
    ZSIZE=$7
fi

if [ -z "$8" ]; then
    PSF_DIR="/beamlines/bl09/controls/user_resources/psf_directory"
else
    PSF_DIR=$8
fi

SOURCEDATA=$4
SOURCEDATADIR=$(dirname "$SOURCEDATA")
SOURCEDATAFILE=$(basename "$SOURCEDATA")

### Copy files to computing nodes ##############################################
WORKDIR="/tmp/bl09_tomo_deconv_wiener_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo "Copying input files to Cluster local disks"
echo "sbcast -p ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}"
sbcast -p ${SOURCEDATA} ${WORKDIR}/${SOURCEDATAFILE}

### MAIN script ################################################################
cd ${WORKDIR}
echo "Running tomo_deconv_wiener"
echo "--------------------------"

# Deconvolve using tomo_deconv_wiener
echo "srun tomo_deconv_wiener ${ZP_DR} ${ENERGY} ${DATE} ${SOURCEDATAFILE} ${DX} ${KW} ${ZSIZE} ${PSF_DIR}"
srun tomo_deconv_wiener ${ZP_DR} ${ENERGY} ${DATE} ${SOURCEDATAFILE} ${DX} ${KW} ${ZSIZE} ${PSF_DIR}
OUTPUT_FILE=`find -name "*_deconv_*"`

### Recovering results #########################################################
echo "Recovering results:"
cd $INIT_DIR
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


