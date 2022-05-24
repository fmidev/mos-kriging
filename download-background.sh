set -ue

makefilename(){
  analtime=$1
  fcst_per=$2
  fcsttime=$(mandtg $analtime + $fcst_per)0000
  analshrt=$(echo $analtime | cut -c5-12)00
  fcstshrt=$(echo $fcsttime | cut -c5-12)
  if [ ${#fcstshrt} -eq 7 ]; then
    fcstshrt="0$fcstshrt"
  fi

  echo F5D$analshrt$fcstshrt"1"
}

download() {
  file=$(makefilename $1 $2)

  if [ -f /tmp/ecmwf/$file ]; then
    sz=$(stat -c %s /tmp/ecmwf/$file)
    if [ $sz -gt 100000 ]; then
       return
    fi
  fi

  set -x
  curl --fail --show-error -o /tmp/ecmwf/$file https://lake.fmi.fi/routines-data/mos/F5D/$file

}

if [ $# -eq 2 ]; then
  base_date=$1
  LL=$2

  download $base_date $LL
else
  HH=00
  base_date=$(date +%Y%m%d)
  steps=$(seq 0 3 144)
  steps="$steps $(seq 150 6 240)"

  for i in $steps; do
    download $base_date $i
  done
fi

