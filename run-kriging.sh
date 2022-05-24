#!/bin/sh

set -uex

DTG=$1
shift

export POSSE_EC=/tmp/ecmwf/
mkdir -p /tmp/out

producer_id=120

if [ $TYPE = "development" ]; then
  producer_id=122
fi

fix_grib_metadata(){
  LL=$1
  filein=$2

  dataDate=$(echo $DTG | cut -c 1-8)
  dataTime=$(echo 100 \* $(echo $DTG | cut -c 9-10) | bc)
#  grib_set -s indicatorOfTypeOfLevel=105,centre=86,generatingProcessIdentifier=$producer_id,dataDate=$dataDate,dataTime=$dataTime,startStep=$fstep,endStep=$LL $filein.orig $filein

  grib_set -S -s indicatorOfTypeOfLevel=105,centre=86,generatingProcessIdentifier=$producer_id,dataDate=$dataDate,dataTime=$dataTime,startStep=$LL,endStep=$LL,timeRangeIndicator=0 -w indicatorOfParameter=167/168/129 $filein out-instant.grib
  grib_set -S -s indicatorOfTypeOfLevel=105,centre=86,generatingProcessIdentifier=$producer_id,dataDate=$dataDate,dataTime=$dataTime,timeRangeIndicator=2 -w indicatorOfParameter=mn2t/mx2t $filein out-aggregated.grib

  grib_set -s level=2 -w shortName!=z out-*.grib $filein

}

do_kriging(){
  DTG=$1
  LL=$2

  # After 144 hours steprange change to 6h interval
  if [ "$LL" -lt "144" ]
  then
    LLINT=3
  else
    LLINT=6
  fi

  FCDTG=`mandtg $DTG + $LL`

  YEAR=`mandtg -year $FCDTG`
  MONTH=`mandtg -month $FCDTG`
  DAY=`mandtg -day $FCDTG`
  HOUR=`mandtg -hour $FCDTG`

  This_step=MOS_${DTG}_${LL}_${YEAR}${MONTH}${DAY}${HOUR}.csv

  fc_out=/tmp/out/fc${DTG}+$(printf "%03d" $LL)h

  This_step_ECbg=fc_${YEAR}${MONTH}${DAY}_${HOUR}.grib

  echo ${DTG}
  echo ${This_step}
  echo ${LL}
  echo ${This_step_ECbg}

  POSSE_STATIONS=/tmp/mos/
  # Do QC on input CSV-files..........
  SizeCSV=`du -b ${POSSE_STATIONS}/${This_step} | awk '{print $1}'`
  if [ $SizeCSV -lt 100000 ]
  then
    echo "WARNING input CSV-file is bad sized!!!  ${This_step}  "
    exit 1
    #echo $HH | mail -s "Kriging DEVDEV ::::: CSV-FILE SIZE PROBLEM =  ${This_step}   ::::" erik.gregow@fmi.fi
  fi

  # Do QC on input EC-files
  SizeEC=`du -b ${POSSE_EC}/background/${This_step_ECbg} | awk '{print $1}'`
  if [ $SizeEC -lt 4000000 ]
  then
    echo "WARNING input EC-file is bad sized!!!  ${This_step_ECbg}  "
    exit 1
  #echo $HH | mail -s "Kriging DEVDEV ::::: EC-FILE SIZE PROBLEM =  ${This_step_ECbg}   ::::" erik.gregow@fmi.fi
  fi

  # Here run the Temperature Kriging

  echo "GRIDDING_${DTG}/fc_${LL} Start: `date`"
 
  if [ "$LL" -lt "240" ]
  then
    Rscript $POSSE_EC/../MOStoECgrid.R -m ${POSSE_STATIONS}/${This_step} -f ${POSSE_EC}/background/${This_step_ECbg} -o ${fc_out} temperature minimumtemperature maximumtemperature dewpoint
  else 
    #Exception because LL=240 has only T and Td, no max/min temperatures.....
    Rscript $POSSE_EC/../MOStoECgrid.R -m ${POSSE_STATIONS}/${This_step} -f ${POSSE_EC}/background/${This_step_ECbg} -o ${fc_out} temperature dewpoint
  fi

  echo "GRIDDING_${DTG}/fc_${LL} Done: `date`"
  fix_grib_metadata $LL $fc_out.grib

  echo "Wrote file $fc_out.grib"
  sh /tmp/copy-to-lake.sh $fc_out.grib
}

for LL in $*; do
  do_kriging $DTG $LL
done
