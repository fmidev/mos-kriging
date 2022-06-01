set -ue

mkdir -p /tmp/mos

download() {
  file=MOS_${1}_${2}_$(mandtg $1 + $2).csv

  if [ -f /tmp/csv/$file ]; then
    sz=$(stat -c %s /tmp/mos/$file)
    if [ $sz -gt 1000 ]; then
       return
    fi
  fi

  set -x
  curl --fail --show-error -o /tmp/mos/$file https://lake.fmi.fi/routines-data/mos/csv/$TYPE/$file

}

if [ $# -eq 2 ]; then
  download $1 $2
else
  HH=00
  base_date=$(date +%Y%m%d)

  steps=$(seq 0 3 144)
  steps="$steps $(seq 150 6 240)"

  for i in $steps; do
    download ${base_date}$HH $i
  done
fi

