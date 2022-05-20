#!/bin/sh

set -uex

DTG=$1
shift

export POSSE_EC=/tmp/ecmwf/
mkdir -p /tmp/out

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

  LL=$LLINT
  FCDTG=`mandtg $DTG + $LLINT`

  YEAR=`mandtg -year $FCDTG`
  MONTH=`mandtg -month $FCDTG`
  DAY=`mandtg -day $FCDTG`
  HOUR=`mandtg -hour $FCDTG`

  This_step=MOS_${DTG}_${LL}_${YEAR}${MONTH}${DAY}${HOUR}.csv

  fc_out=/tmp/out/init_${DTG}_${LL}_fc_${YEAR}${MONTH}${DAY}${HOUR}

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
  echo "Wrote file $fc_out"
  export DTG
  export TYPE=development
  sh copy-to-lake.sh $fc_out
}

for LL in $*; do
  do_kriging $DTG $LL
done
