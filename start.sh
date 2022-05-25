set -eux

DTG=$1

shift

rm -f /tmp/ecmwf/Comb/*

for LL in $*; do
  sh convert.sh $DTG $LL
  sh download-mos.sh $DTG $LL
  sh run-kriging.sh $DTG $LL
done
