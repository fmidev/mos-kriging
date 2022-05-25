set -eux

DTG=$1

shift

rm -f /tmp/ecmwf/Comb/*

# If processing starts mid-timeseries, we have to pre-fetch earlier
# fields so that min/max can properly be produced.

FIRST=$1

if [ $FIRST -gt 3 ]; then
  BEG=$(expr $FIRST - 12)

  if [ $BEG -lt 0]; then
    BEG=0
  fi
  while [ $BEG -lt $FIRST ]; do
    sh convert.sh $DTG $BEG

    if [ $BEG -lt 144 ]; then
      BEG=$(expr $BEG + 3)
    else
      BEG=$(expr $BEG + 6)
    fi
  done
fi

for LL in $*; do
  sh convert.sh $DTG $LL
  sh download-mos.sh $DTG $LL
  sh run-kriging.sh $DTG $LL
done
