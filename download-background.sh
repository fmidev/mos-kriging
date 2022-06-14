set -ue

path=/tmp/ecmwf/background

mkdir -p $path

download() {
  fcdatetime=$(mandtg $1 + $2)
  fcdate=$(echo $fcdatetime | cut -c 1-8)
  fctime=$(echo $fcdatetime | cut -c 9-10)
  file=fc_${fcdate}_${fctime}.grib

  if [ -f $path/$file ]; then
    sz=$(stat -c %s $path/$file)
    if [ $sz -gt 100000 ]; then
       return
    fi
  fi

  set -x
  curl --fail --show-error -o $path/$file https://lake.fmi.fi/routines-data/mos/background/$1/$file

}

base_date=$1
LL=$2

download $base_date $LL
