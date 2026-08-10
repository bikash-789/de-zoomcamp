#!/bin/bash

set -e

TAXI=$1
YEAR=$2

URL_PREFIX="https://d37ci6vzurychx.cloudfront.net/trip-data"

for i in {1..12}; do
    FMONTH=$(printf "%02d" "$i")

    URL="${URL_PREFIX}/${TAXI}_tripdata_${YEAR}-${FMONTH}.parquet"

    LOCAL_PREFIX="data/pqt/${TAXI}/${YEAR}/${FMONTH}"
    LOCAL_FILE="${TAXI}_tripdata_${YEAR}_${FMONTH}.parquet"
    LOCAL_PATH="${LOCAL_PREFIX}/${LOCAL_FILE}"

    mkdir -p "$LOCAL_PREFIX"

    curl -L "$URL" -o "$LOCAL_PATH"
done