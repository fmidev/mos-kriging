#!/bin/sh
#---------------------------------------------------------------------------
set -xeu

# . /lustre/apps/lapsrut/POSSE_GRID/DEV/POSSE_profile.sh

export TZ=GMT0BST

export POSSE_EC=/tmp/ecmwf/
mkdir -p $POSSE_EC/TEMP_kriging ${POSSE_EC}/Comb ${POSSE_EC}/background
cd ${POSSE_EC}/TEMP_kriging

DTG=$1
shift

Datum=`echo $DTG |cut -c5-10`

#*********************************************
# Clean up old files, so they are not used....
rm -rf ${POSSE_EC}/background/*.grib
#rm -rf ${POSSE_EC}/Comb/*.grib
rm -rf ${POSSE_EC}/TEMP_kriging/F5D*

#*********************************************

process_3h(){
  NDTG=$1
  LL=$2
  NDTG=$(mandtg $NDTG + $LL)
  YEAR=`mandtg -year $NDTG`
  MONTH=`mandtg -month $NDTG`
  DAY=`mandtg -day $NDTG`
  HOUR=`mandtg -hour $NDTG`
  FCLENGTH=${MONTH}${DAY}${HOUR}

  #Take care of mx2t6 and mn2t6 for every 3'rd hour step, EC does not contain these.....
  DTG_p3=`mandtg $NDTG + 3`
  YEAR_p3=`mandtg -year $DTG_p3`
  MONTH_p3=`mandtg -month $DTG_p3`
  DAY_p3=`mandtg -day $DTG_p3`
  HOUR_p3=`mandtg -hour $DTG_p3`
  FCLENGTH_p3=${MONTH_p3}${DAY_p3}${HOUR_p3}

##########

  cd ${POSSE_EC}/TEMP_kriging/

  #Set correct stepRange to the analysis file
  grib_set -s stepRange=${LL} ${POSSE_EC}/F5D${Datum}00${Datum}001 ${POSSE_EC}/TEMP_kriging/F5D${Datum}00${Datum}001_an_${LL}

  #Copy the analysis file into the fc-file
  grib_copy ${POSSE_EC}/TEMP_kriging/F5D${Datum}00${Datum}001_an_${LL} ${POSSE_EC}/F5D${Datum}00${FCLENGTH}001 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1

#########
  #If it is hour: 03, 09, 15 or 21, then the mx2t6and mn2t6 are missing and needs to be copied into these GRIB-files (Note: copied from the NEXT time-step!!
  if [ "${HOUR}" = "03" -o "${HOUR}" = "09" -o "${HOUR}" = "15" -o "${HOUR}" = "21" ]
  then

    grib_copy -w shortName=mx2t6 ${POSSE_EC}/F5D${Datum}00${FCLENGTH_p3}001 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_max
    grib_copy -w shortName=mn2t6 ${POSSE_EC}/F5D${Datum}00${FCLENGTH_p3}001 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_min

    grib_copy ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_max ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_min ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p0

#Else if it is another hour, just naming correctly with ..._p0
  else
    mv ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p0

  fi
##########

#Take out the surface parameters only
  grib_copy -w typeOfLevel=surface ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p0 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p1

  #Change the parameters naming from 121 to 201 and 122 to 202.... needed because of grib-coding
  grib_set -s paramId=201 -w paramId=121 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p1 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p2
  grib_set -s paramId=202 -w paramId=122 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p2 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p3

  #Change the parameters naming from mx2t6 to mx2t and mn2t6 to mn2t...... because of grib-coding
  grib_set -s shortName=mx2t -w shortName=mx2t6 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p3 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p4
  grib_set -s shortName=mn2t -w shortName=mn2t6 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p4 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p5

  #Set the right stepRange for this fc-file time-step
  grib_set -s stepRange=${LL} ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p5 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6

  #Here do the calculation of Tmax and Tmin over several time-steps and then put variable into final Grib-file

  #For each time-step pull out the max and min, put into separate file
  cdo -select,name=var201 F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 mx2t_${YEAR}${MONTH}${DAY}_${HOUR}.grib
  cdo -select,name=var202 F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 mn2t_${YEAR}${MONTH}${DAY}_${HOUR}.grib

  #Move the max/min files to other directory for combining them with other files
  mv mx2t_${YEAR}${MONTH}${DAY}_${HOUR}.grib ${POSSE_EC}/Comb/
  mv mn2t_${YEAR}${MONTH}${DAY}_${HOUR}.grib ${POSSE_EC}/Comb/

  #If it is hour: 06 or 18, then combine the Tmax and Tmin!!
  if [ "${HOUR}" = "06" -o "${HOUR}" = "18" ]
  then

    #cd /lustre/tmp/lapsrut/Background_model/Dissemination/Europe/Comb/
    cd $POSSE_EC/Comb

    #Calculate the average value over a set of time-steps, put into new file
    cdo ensmean mx2t_*.grib prev12h_mx2t${YEAR}${MONTH}${DAY}_${HOUR}.grib
    cdo ensmean mn2t_*.grib prev12h_mn2t${YEAR}${MONTH}${DAY}_${HOUR}.grib

    #Select each parameter and put into new file-name
    cdo -select,name=var167 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 ./2t_${YEAR}${MONTH}${DAY}_${HOUR}.grib
    cdo -select,name=var168 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 ./2d_${YEAR}${MONTH}${DAY}_${HOUR}.grib
    cdo -select,name=var172 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 ./lsm_${YEAR}${MONTH}${DAY}_${HOUR}.grib
    cdo -select,name=var129 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 ./z_${YEAR}${MONTH}${DAY}_${HOUR}.grib

    #Then copy the parameters to new file and to the output-directory, here take the recalculated previous 12h max/min temperatures
    grib_copy 2t_${YEAR}${MONTH}${DAY}_${HOUR}.grib 2d_${YEAR}${MONTH}${DAY}_${HOUR}.grib prev12h_mx2t${YEAR}${MONTH}${DAY}_${HOUR}.grib prev12h_mn2t${YEAR}${MONTH}${DAY}_${HOUR}.grib lsm_${YEAR}${MONTH}${DAY}_${HOUR}.grib z_${YEAR}${MONTH}${DAY}_${HOUR}.grib ${POSSE_EC}/background/fc_${YEAR}${MONTH}${DAY}_${HOUR}.grib

    #Important to clean-up before next round of files comes in. 
    rm -rf ${POSSE_EC}/Comb/*.grib

  else 
    #If we are not at hour 06 or 18, then copy/extract the needed parameters directly to output-file and directory, without further manipulation
    grib_copy -w shortName=2t/2d/mx2t/mn2t/lsm/z ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 ${POSSE_EC}/background/fc_${YEAR}${MONTH}${DAY}_${HOUR}.grib

  fi


  ###### Take care of the startStep, endStep in Grib-file ######

  cd ${POSSE_EC}/background/

  fc_out=fc_${YEAR}${MONTH}${DAY}_${HOUR}.grib

  if [ "${LL}" = "3" -o "${LL}" = "6" ]
  then
     LLm6=0
     LLm12=0
  elif [ "${LL}" = "9" ]
  then 
     LLm6=3
     LLm12=0
  elif [ "${LL}" = "12" ]
  then 
     LLm6=6
     LLm12=0
  else
     LLm6=`expr ${LL} - 6`
     LLm12=`expr ${LL} - 12`
  fi

  if [ "${HOUR}" = "06" -o "${HOUR}" = "18" ]
  then

#Need to change this timeRangeIndicator in order to do the rest of grib_set
    grib_set -s timeRangeIndicator=4 -w shortName=2t/2d/lsm/z/mn2t/mx2t ${fc_out} ${fc_out}_A

    grib_set -s startStep=${LL} -w shortName=2t/2d/lsm/z ${fc_out}_A ${fc_out}_B
    grib_set -s endStep=${LL} -w shortName=2t/2d/lsm/z ${fc_out}_B ${fc_out}_C

    grib_set -s startStep=${LLm12} -w shortName=mn2t/mx2t ${fc_out}_C ${fc_out}_D
    grib_set -s endStep=${LL} -w shortName=mn2t/mx2t ${fc_out}_D ${fc_out}_E

    grib_set -s dataDate=${YEAR}${MONTH}${DAY} ${fc_out}_E ${fc_out}_F
    grib_set -s dataTime=${HOUR} ${fc_out}_F ${fc_out}_G

    mv ${fc_out}_G ${fc_out}
    rm -rf ${fc_out}_*

  else

    #Need to change this timeRangeIndicator in order to do the rest of grib_set
    grib_set -s timeRangeIndicator=4 -w shortName=2t/2d/lsm/z/mn2t/mx2t ${fc_out} ${fc_out}_A

    grib_set -s startStep=${LL} -w shortName=2t/2d/lsm/z ${fc_out}_A ${fc_out}_B
    grib_set -s endStep=${LL} -w shortName=2t/2d/lsm/z ${fc_out}_B ${fc_out}_C

    grib_set -s startStep=${LLm6} -w shortName=mn2t/mx2t ${fc_out}_C ${fc_out}_D
    grib_set -s endStep=${LL} -w shortName=mn2t/mx2t ${fc_out}_D ${fc_out}_E

    grib_set -s dataDate=${YEAR}${MONTH}${DAY} ${fc_out}_E ${fc_out}_F
    grib_set -s dataTime=${HOUR} ${fc_out}_F ${fc_out}_G

    mv ${fc_out}_G ${fc_out}
    rm -rf ${fc_out}_*

  fi

  cd ${POSSE_EC}/TEMP_kriging/


}

process_6h() {

  NDTG=$1
  LL=$2
  NDTG=$(mandtg $NDTG + $LL)
  YEAR=`mandtg -year $NDTG`
  MONTH=`mandtg -month $NDTG`
  DAY=`mandtg -day $NDTG`
  HOUR=`mandtg -hour $NDTG`
  FCLENGTH=${MONTH}${DAY}${HOUR}

#Take care of mx2t6 and mn2t6 for every 6'th hour step, should not be needed, only 00, 06, 12, 18 should be used after 144h.....
# DTG_p6=`mandtg $DTG + 6` 
  DTG_p6=`mandtg $NDTG + 0`
  YEAR_p6=`mandtg -year $DTG_p6`
  MONTH_p6=`mandtg -month $DTG_p6`
  DAY_p6=`mandtg -day $DTG_p6`
  HOUR_p6=`mandtg -hour $DTG_p6`
  FCLENGTH_p6=${MONTH_p6}${DAY_p6}${HOUR_p6}

#########

  cd ${POSSE_EC}/TEMP_kriging/

  #Set correct stepRange to the analysis file
  grib_set -s stepRange=${LL} ${POSSE_EC}/F5D${Datum}00${Datum}001 ${POSSE_EC}/TEMP_kriging/F5D${Datum}00${Datum}001_an_${LL}

  #Copy the analysis file into the fc-file
  grib_copy ${POSSE_EC}/TEMP_kriging/F5D${Datum}00${Datum}001_an_${LL} ${POSSE_EC}/F5D${Datum}00${FCLENGTH}001 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1

#########
  #If it is hour: 03, 09, 15 or 21, then the mx2t6and mn2t6 are missing and needs to be copied into these GRIB-files (Note: copied from the NEXT time-step!!
  if [ "${HOUR}" = "03" -o "${HOUR}" = "09" -o "${HOUR}" = "15" -o "${HOUR}" = "21" ]
  then

    grib_copy -w shortName=mx2t6 ${POSSE_EC}/F5D${Datum}00${FCLENGTH_p3}001 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_max
    grib_copy -w shortName=mn2t6 ${POSSE_EC}/F5D${Datum}00${FCLENGTH_p3}001 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_min

    grib_copy ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_max ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_min ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p0

#Else if it is another hour, just naming correctly with ..._p0
  else
    mv ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p0

  fi
##########

#Take out the surface parameters only
  grib_copy -w typeOfLevel=surface ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p0 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p1

  #Change the parameters naming from 121 to 201 and 122 to 202.... needed because of grib-coding
  grib_set -s paramId=201 -w paramId=121 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p1 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p2
  grib_set -s paramId=202 -w paramId=122 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p2 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p3

  #Change the parameters naming from mx2t6 to mx2t and mn2t6 to mn2t...... because of grib-coding
  grib_set -s shortName=mx2t -w shortName=mx2t6 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p3 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p4
  grib_set -s shortName=mn2t -w shortName=mn2t6 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p4 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p5

  #Set the right stepRange for this fc-file time-step
  grib_set -s stepRange=${LL} ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p5 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6

  ###################################################################
  #Here do the calculation of Tmax and Tmin over several time-steps and then put variable into final Grib-file

  #For each time-step pull out the max and min, put into separate file
  cdo -select,name=var201 F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 mx2t_${YEAR}${MONTH}${DAY}_${HOUR}.grib
  cdo -select,name=var202 F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 mn2t_${YEAR}${MONTH}${DAY}_${HOUR}.grib

  #Move the max/min files to other directory for combining them with other files
  mv mx2t_${YEAR}${MONTH}${DAY}_${HOUR}.grib ${POSSE_EC}/Comb/
  mv mn2t_${YEAR}${MONTH}${DAY}_${HOUR}.grib ${POSSE_EC}/Comb/


  #If it is hour: 06 or 18, then combine the Tmax and Tmin!!
  if [ "${HOUR}" = "06" -o "${HOUR}" = "18" ]
  then

    #cd /lustre/tmp/lapsrut/Background_model/Dissemination/Europe/Comb/
    cd $POSSE_EC/Comb
#Calculate the average value over a set of time-steps, put into new file

#Example singe files
#cdo ensmax output_mx2t_03.grib output_mx2t_06.grib test2.grib
#cdo ensmean output_mx2t_03.grib output_mx2t_06.grib test2.grib
#Example with many files
#cdo ensmax -cat output_mx2t_*.grib test3.grib
#cdo ensmean -cat output_mx2t_*.grib test3.grib

    cdo ensmean mx2t_*.grib prev12h_mx2t${YEAR}${MONTH}${DAY}_${HOUR}.grib
    cdo ensmean mn2t_*.grib prev12h_mn2t${YEAR}${MONTH}${DAY}_${HOUR}.grib

#Select each parameter and put into new file-name
    cdo -select,name=var167 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 ./2t_${YEAR}${MONTH}${DAY}_${HOUR}.grib
    cdo -select,name=var168 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 ./2d_${YEAR}${MONTH}${DAY}_${HOUR}.grib
    cdo -select,name=var172 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 ./lsm_${YEAR}${MONTH}${DAY}_${HOUR}.grib
    cdo -select,name=var129 ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 ./z_${YEAR}${MONTH}${DAY}_${HOUR}.grib

    #Then copy the parameters to new file and to the output-directory, here take the recalculated previous 12h max/min temperatures
    grib_copy 2t_${YEAR}${MONTH}${DAY}_${HOUR}.grib 2d_${YEAR}${MONTH}${DAY}_${HOUR}.grib prev12h_mx2t${YEAR}${MONTH}${DAY}_${HOUR}.grib prev12h_mn2t${YEAR}${MONTH}${DAY}_${HOUR}.grib lsm_${YEAR}${MONTH}${DAY}_${HOUR}.grib z_${YEAR}${MONTH}${DAY}_${HOUR}.grib ${POSSE_EC}/background/fc_${YEAR}${MONTH}${DAY}_${HOUR}.grib

    #Important to clean-up before next round of files comes in. 
    rm -rf ${POSSE_EC}/Comb/*.grib


  else 
    #If we are not at hour 06 or 18, then copy/extract the needed parameters directly to output-file and directory, without further manipulation
    grib_copy -w shortName=2t/2d/mx2t/mn2t/lsm/z ${POSSE_EC}/TEMP_kriging/F5D_${YEAR}${MONTH}${DAY}_${HOUR}.grib1_p6 ${POSSE_EC}/background/fc_${YEAR}${MONTH}${DAY}_${HOUR}.grib

  fi

  cd ${POSSE_EC}/TEMP_kriging/

###### Take care of the startStep, endStep in Grib-file ######

  cd ${POSSE_EC}/background

  fc_out=fc_${YEAR}${MONTH}${DAY}_${HOUR}.grib

  if [ "${LL}" = "3" -o "${LL}" = "6" ]
  then
    LLm6=0
    LLm12=0
  elif [ "${LL}" = "9" ]
  then 
    LLm6=3
    LLm12=0
  elif [ "${LL}" = "12" ]
  then 
    LLm6=6
    LLm12=0
  else
    LLm6=`expr ${LL} - 6`
    LLm12=`expr ${LL} - 12`
  fi

  if [ "${HOUR}" = "06" -o "${HOUR}" = "18" ]
  then

    #Need to change this timeRangeIndicator in order to do the rest of grib_set
    grib_set -s timeRangeIndicator=4 -w shortName=2t/2d/lsm/z/mn2t/mx2t ${fc_out} ${fc_out}_A

    grib_set -s startStep=${LL} -w shortName=2t/2d/lsm/z ${fc_out}_A ${fc_out}_B
    grib_set -s endStep=${LL} -w shortName=2t/2d/lsm/z ${fc_out}_B ${fc_out}_C

    grib_set -s startStep=${LLm12} -w shortName=mn2t/mx2t ${fc_out}_C ${fc_out}_D
    grib_set -s endStep=${LL} -w shortName=mn2t/mx2t ${fc_out}_D ${fc_out}_E

    grib_set -s dataDate=${YEAR}${MONTH}${DAY} ${fc_out}_E ${fc_out}_F
    grib_set -s dataTime=${HOUR} ${fc_out}_F ${fc_out}_G

    mv ${fc_out}_G ${fc_out}
    rm -rf ${fc_out}_*

  else

    #Need to change this timeRangeIndicator in order to do the rest of grib_set
    grib_set -s timeRangeIndicator=4 -w shortName=2t/2d/lsm/z/mn2t/mx2t ${fc_out} ${fc_out}_A

    grib_set -s startStep=${LL} -w shortName=2t/2d/lsm/z ${fc_out}_A ${fc_out}_B
    grib_set -s endStep=${LL} -w shortName=2t/2d/lsm/z ${fc_out}_B ${fc_out}_C

    grib_set -s startStep=${LLm6} -w shortName=mn2t/mx2t ${fc_out}_C ${fc_out}_D
    grib_set -s endStep=${LL} -w shortName=mn2t/mx2t ${fc_out}_D ${fc_out}_E

    grib_set -s dataDate=${YEAR}${MONTH}${DAY} ${fc_out}_E ${fc_out}_F
    grib_set -s dataTime=${HOUR} ${fc_out}_F ${fc_out}_G

    mv ${fc_out}_G ${fc_out}
    rm -rf ${fc_out}_*

  fi



}

sh /tmp/download-background.sh $DTG 0

for LL in $*; do 
  sh /tmp/download-background.sh $DTG $LL
  STEP=3
  if [ $LL -ge 144 ]; then
    STEP=6
  fi

  NEXT_STEP=`expr $LL + $STEP`

  if [ $NEXT_STEP -le 240 ]; then
    sh /tmp/download-background.sh $DTG $NEXT_STEP
  fi

  if [ $LL -gt 144 ]; then
    process_6h $DTG $LL
  else
    process_3h $DTG $LL
  fi

done

exit 0

chmod 644 ${POSSE_EC}/background/*
