#!/bin/bash -e

# Script to setup the Docker mirror environment variables

print_help() {
  echo """
usage: $0 -p -d -a
Create the environment file for the Waggle docker registry mirror service.
 -p : output path for the environment file
 -d : default registry remote URL
 -a : alternate (factory) registry remote URL
"""
}

DEFAULT_REMOTEURL=
FACTORY_REMOTEURL=
PATH=
while getopts "p:d:a:?" opt; do
  case $opt in
    p) # output path
      PATH=$(/usr/bin/realpath $OPTARG)
      ;;
    d) # default remote url
      DEFAULT_REMOTEURL=$OPTARG
      ;;
    a) # alternate remote url
      FACTORY_REMOTEURL=$OPTARG
      ;;
    ?|*)
      print_help
      exit 1
      ;;
  esac
done

# sanity check intput
if [ -z "${PATH}" ]; then
  echo "ERROR: output path (-p) is required."
  exit 1
fi

if [ -z "${DEFAULT_REMOTEURL}" ]; then
  echo "ERROR: default remote URL (-d) is required."
  exit 2
fi

if [ -z "${FACTORY_REMOTEURL}" ]; then
  echo "ERROR: alternate (factory) remote URL (-a) is required."
  exit 3
fi

# empty the file
> ${PATH}

# prioritize the alt url, else use default
CHOSEN_REMOTEURL=${DEFAULT_REMOTEURL}
if /usr/bin/curl --max-time 30 ${FACTORY_REMOTEURL}/v2/_catalog; then
  CHOSEN_REMOTEURL=${FACTORY_REMOTEURL}
fi
echo "Using remote URL: '${CHOSEN_REMOTEURL}'"
echo "REGISTRY_PROXY_REMOTEURL=${CHOSEN_REMOTEURL}" >> ${PATH}