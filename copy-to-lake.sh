#!/bin/sh

set -uxe

date=$(date +%Y%m%d)

for filename in $*; do
  s3cmd -v \
    --host $S3_HOSTNAME \
    --host-bucket=routines-data.$S3_HOSTNAME \
    --access_key $S3_ACCESS_KEY_ID \
    --secret_key $S3_SECRET_ACCESS_KEY \
    put $filename s3://mos-data/$TYPE/$DTG/$(basename $filename)
done

