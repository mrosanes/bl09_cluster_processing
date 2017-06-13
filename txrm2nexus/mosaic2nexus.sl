#!/bin/bash

################################################################################
# (C) Copyright 2017 Marc Rosanes Siscart
# The program is distributed under the terms of the GNU General Public License.
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
################################################################################

################################################################################
## mosaic2nexus SLURM script for Cluster execution
################################################################################

### Input parameters ###########################################################
# 1: Input: XRM file containing the mosaic raw data image
# 2: Input: XRM file containing the the FF image
################################################################################

### SLURM environment ##########################################################
#SBATCH -p short # partition (queue) (it can be short, medium, or beamline)
#SBATCH -N 1
#SBATCH --mail-user=mrosanes@cells.es 
#SBATCH -o /beamlines/bl09/controls/cluster/logs/bl09_mosaic2nexus_%N_%j.out
#SBATCH -e /beamlines/bl09/controls/cluster/logs/bl09_mosaic2nexus_%N_%j.err
#SBATCH --tmp=8G
################################################################################

echo `date`
start=`date +%s`

### Copy files to computing nodes ##############################################
INIT_DIR=`pwd`

SOURCEDATA_XRM=$1
SOURCEDATA_XRM_DIR=$(dirname ${SOURCEDATA_XRM})
SOURCEDATA_XRM_FILE=$(basename ${SOURCEDATA_XRM})

SOURCEDATA_XRM_FF=$2
SOURCEDATA_XRM_FF_DIR=$(dirname ${SOURCEDATA_XRM_FF})
SOURCEDATA_XRM_FF_FILE=$(basename ${SOURCEDATA_XRM_FF})

WORKDIR="/tmp/bl09_mosaic2nexus_${SLURM_JOBID}"
mkdir -p $WORKDIR
echo $'\nCopying input files to Cluster local disks'
echo "sbcast ${SOURCEDATA_XRM} ${WORKDIR}/${SOURCEDATA_XRM_FILE}"
sbcast ${SOURCEDATA_XRM} ${WORKDIR}/${SOURCEDATA_XRM_FILE}
echo "sbcast ${SOURCEDATA_XRM_FF} ${WORKDIR}/${SOURCEDATA_XRM_FF_FILE}"
sbcast ${SOURCEDATA_XRM_FF} ${WORKDIR}/${SOURCEDATA_XRM_FF_FILE}

### MAIN script ################################################################
cd ${WORKDIR}
echo $'\n\n'
echo "Running mosaic2nexus"
echo "srun mosaic2nexus ${SOURCEDATA_XRM_FILE} ${SOURCEDATA_XRM_FF_FILE} ${@:3}"
srun mosaic2nexus ${SOURCEDATA_XRM_FILE} ${SOURCEDATA_XRM_FF_FILE} "${@:3}"

### Recovering results #########################################################
echo $'\n\nRecovering results:'
cd $INIT_DIR
OUTPUT_FILE=${WORKDIR}/${SOURCEDATA_XRM_FILE%.xrm}.hdf5
OUT_FILE_NAME=$(basename $OUTPUT_FILE)
echo "sgather -kpf $OUTPUT_FILE  $SOURCEDATA_XRM_DIR/$OUT_FILE_NAME"
sgather -kpf $OUTPUT_FILE $SOURCEDATA_XRM_DIR/$OUT_FILE_NAME
################################################################################

### Fix output file name by removing the node name from the suffix #############
mv $SOURCEDATA_XRM_DIR/$OUT_FILE_NAME.`hostname` $SOURCEDATA_XRM_DIR/$OUT_FILE_NAME
################################################################################

### Time spent for processing the job ##########################################
end=`date +%s`
runtime=$((end-start))
echo $'\n'
echo "Time to run: $runtime seconds"
################################################################################
