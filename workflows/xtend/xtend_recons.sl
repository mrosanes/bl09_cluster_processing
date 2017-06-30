#!/bin/bash

## WORKFLOW: 
# - xrm2nexus
# - normalization
# - crop
# - align the images for each angle (multifocus)
# - fuse
# - deconvolve
# - align using ctalign
# - reconstruction

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
# 8: number of iterations: used by tomo3d reconstruction software
# 9: height: number of output slices; used by tomo3d reconstruction software
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_xtend_recons_%N.%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_xtend_recons_%N.%j.err
#SBATCH --tmp=16G
#SBATCH -N 1
#SBATCH -c 48
################################################################################

echo `date`
start=`date +%s`

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/hpcsoftware/MATLAB/MATLAB_Runtime/v90/runtime/glnxa64:/mnt/hpcsoftware/MATLAB/MATLAB_Runtime/v90/bin/glnxa64:/mnt/hpcsoftware/MATLAB/MATLAB_Runtime/v90/sys/os/glnxa64

### Copy files to computing nodes ##############################################

root_path=`pwd`
SOURCEDATADIR=$1
OUTDIR=$2
OUTDIR=$root_path/$OUTDIR
ANGLES="angles.tlt"
threads=48

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

if [ -z "$8" ]; then
    ITERATIONS=30
else
    ITERATIONS=$8
fi

if [ -z "$9" ]; then
    HEIGHT=500
else
    HEIGHT=$9
fi


WORKDIR="/tmp/bl09_xtend_recons_${SLURM_JOBID}"
INPUTDATACLUSTERDIR=$WORKDIR/inputdata
OUTPUTDATACLUSTERDIR="${WORKDIR}/output"

mkdir -p $INPUTDATACLUSTERDIR
mkdir -p $OUTPUTDATACLUSTERDIR


### Copy input data to Cluster local storage ###################################
echo "Copying input files to Cluster local disks"
echo "sbcast from ${SOURCEDATADIR} to ${INPUTDATACLUSTERDIR}"
for f in $SOURCEDATADIR/*; do
    SOURCEDATAFILE=$(basename $f)
    sbcast -p ${f} ${INPUTDATACLUSTERDIR}/${SOURCEDATAFILE}
done
echo "-------------------------------------------------------------------------"
################################################################################


### MAIN WORKFLOW  #############################################################
# Apply xrm2nexus #
echo "Running xrm2nexus"
echo "srun xrm2nexus ${INPUTDATACLUSTERDIR} --output-dir-name ${OUTPUTDATACLUSTERDIR}"
srun xrm2nexus ${INPUTDATACLUSTERDIR} --output-dir-name ${OUTPUTDATACLUSTERDIR}
echo "-------------------------------------------------------------------------"

# Reorganize files in folders by energies
echo "Reorganize files in folders by energies"
for dir in $( ls -d $OUTPUTDATACLUSTERDIR/* ); do
    cd $dir
    for filename in $( ls *.hdf5 ); do
                
        energy=`echo $filename | cut -d'_' -f3`

        if [ ! -d "$energy" ]; then
            mkdir -p $energy
        fi
        
        mv $filename $energy
        
    done
    cd ..
done
cd $WORKDIR
echo "-------------------------------------------------------------------------"

# normalize, crop and convert the hdf5 to mrc
#Frame + 1 col
echo "normalize, crop and convert the hdf5 to mrc"
CROPTYPE=2
for i in $( ls $OUTPUTDATACLUSTERDIR/*/*/*.hdf5 ); do

    cd `dirname $i`
    echo "srun hdf2normcrop $i $CROPTYPE "
    srun hdf2normcrop $i $CROPTYPE   
    CROP_FILE_NAME=${i%.*}_norm_crop.hdf5
    echo "srun extract_angle $CROP_FILE_NAME"
    srun extract_angle $CROP_FILE_NAME
    echo "scipion xmipp_image_convert -i $CROP_FILE_NAME -o ${i%.*}_norm_crop.mrc"
    srun scipion xmipp_image_convert -i $CROP_FILE_NAME -o ${i%.*}_norm_crop.mrc

done
cd $WORKDIR
echo "-------------------------------------------------------------------------"


for dir in $( ls -d $OUTPUTDATACLUSTERDIR/*/* ); do
    cd $dir 

    echo "#####################################################################"
    echo $dir 
    echo "#####################################################################"

    echo "-----ALIGN PROJECTIONS AT DIFFERENT FOCI FOR EACH GIVEN ANGLE------"
    # At each angle align the projections of the samples at many foci: 
    # multifocus (different ZP, same angle). 
    mrc_array=($(ls *_norm_crop.mrc))
    reference=${mrc_array[1]}
    array=${mrc_array[@]/$reference}
    for e_mrc in ${array[@]}; do
        FIJI_PATHS=$FIJI_HOME/ImageJ-linux64:$FIJI_PLUGINS/TomoJ_2.32-jar-with-dependencies.jar:$FIJI_PLUGINS/TomoJ/Eftem_TomoJ_1.03.jar
        srun java -cp $FIJI_PATHS eftemtomoj.EFTEM_TomoJ -tsSignal ${dir}/${reference} 1 1 -tsBg ${dir}/${e_mrc} 2 1 -align NMI 0
    done
    echo "--------------------------------------------------------------------"

    # Rename output files. fiji add .mrc extension in the names
    for mrc in ${mrc_array[@]}; do
        fixed_name=${mrc%.*}
        mv ${mrc}_aligned.tif  ${fixed_name}_aligned.tif
        mv ${mrc}_aligned.transf ${fixed_name}_aligned.transf
    done

    echo "-------------------AVERAGE IMAGES--------------------------"
    # Fusion addition  (works with any foci number)
    n_zp_pos=${#mrc_array[@]}
    samplename=`echo ${mrc_array[0]} | cut -d "-" -f 1`
    fusename=${samplename}FS.mrc

    # mrc array without the two first elements
    ref_tif=${reference%.*}_aligned.tif

    for tif in ${array[@]}; do
        tif_name=${tif%.*}_aligned.tif
        if [ ! -f ${fusename} ]; then
            srun scipion xmipp_image_operate ${ref_tif} --plus $tif_name -o ${fusename}
        else
            srun scipion xmipp_image_operate ${fusename} --plus ${tif_name}
        fi
    done
    echo "srun scipion xmipp_image_operate ${fusename} --divide $n_zp_pos"
    srun scipion xmipp_image_operate ${fusename} --divide $n_zp_pos
    echo "-----------------------------------------------------------"

    DATE=$(echo $fusename | cut -d'_' -f 1)
    ENERGY=$(echo $fusename | cut -d'_' -f 3)
    echo ${fusename}
    echo $DATE
    echo $ENERGY
    echo `pwd`
    echo "----------DECONVOLUTION:----------"
    echo "srun tomo_deconv_wiener ${ZP_DR} ${ENERGY} ${DATE} ${fusename} ${DX} ${KW} ${ZSIZE} ${PSF_DIR}"
    srun tomo_deconv_wiener ${ZP_DR} ${ENERGY} ${DATE} ${fusename} ${DX} ${KW} ${ZSIZE} ${PSF_DIR}
    echo "----------------------------------"

    echo "ALIGNMENT BETWEEN THE PROJECTIONS AT DIFFERENT ANGLES:-----"
    DECONV_FILE=`find -name "*_deconv_*"`
    mrc2hdf $DECONV_FILE
    DECONV_FILE_HDF=${DECONV_FILE%.mrc}.hdf5
    echo "srun ctalign $DECONV_FILE_HDF"
    srun ctalign $DECONV_FILE_HDF
    echo "-----------------------------------------------------------"

    # From hdf5 to mrc
    ALIGNED_HDF=`find -name "*_ali.hdf5"`
    align_tree_hdf5='FastAligned/tomo_aligned@'${ALIGNED_HDF}
    ALIGNED_MRC=${ALIGNED_HDF%.hdf5}.mrc
    echo "srun scipion xmipp_image_convert -i $align_tree_hdf5 -o $ALIGNED_MRC"
    srun scipion xmipp_image_convert -i $align_tree_hdf5 -o $ALIGNED_MRC
    sleep 2
    
    echo "------RECONSTRUCTION AND CHANGING VOLUME AXIS:-------------"
    # Reconstruct
    RECONS_XZY=${ALIGNED_MRC%_ali.mrc}_recons.xzy
    echo "srun tomo3d -v 1 -l $ITERATIONS -z $HEIGHT -S -a $ANGLES -i $ALIGNED_MRC -o $RECONS_XZY"
    srun tomo3d -v 1 -l $ITERATIONS -z $HEIGHT -S -a $ANGLES -i $ALIGNED_MRC -t $threads -H -o $RECONS_XZY
    RECONS_XYZ=${RECONS_XZY%.xzy}_recons.xyz
    echo "srun trimvol -yz $RECONS_XZY $RECONS_XYZ"
    srun trimvol -yz $RECONS_XZY $RECONS_XYZ
    sleep 1
    rm $RECONS_XZY

    RECONS_MRC=${fusename%.mrc}_recons.mrc
    mv $RECONS_XYZ $RECONS_MRC
    echo "-----------------------------------------------------------"

done

cd $WORKDIR

################################################################################



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
        if [[ $f_basename == *"_recons.mrc" ]]; then
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


cd $root_path

### Time spent for processing the job ##########################################
end=`date +%s`
runtime=$((end-start))
echo "Time to run: $runtime seconds"
################################################################################

