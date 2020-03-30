#!/usr/bin/env bash

usage () {
  echo "Usage: build-test.sh [-n]"
  echo "Builds a docker image using the local dockerfile,"
  echo "and attempts to mount in some simple test files to see if the"
  echo "container can actually build them"
  echo "Options:"
  echo "   -n   No Build, skip the build step and assume the container exists."
  echo "   -c   Cleanup after - remove the test image and container definitions"
  }

set -e # Return error code of sub-content.

#https://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
REPO_PATH="$( cd "$(dirname "$0")" || exit ; pwd -P )"
TEST_IMAGE_NAME="latexlilypond-test"
NO_BUILD=false # Assume we will rebuild unless told otherwise
DOCKER_WORKDIR="/workdir"
CLEANUP=false

while getopts chn option; do
  case "${option}" in
    c) CLEANUP=true;;
    n) NO_BUILD=true;;
    h) usage; exit;;
    \? ) echo "Unknown option: -$OPTARG" >&2; usage; exit 1;;
    :  ) echo "Missing option argument for -$OPTARG" >&2; usage; exit 1;;
    *  ) echo "Unimplemented option: -$OPTARG" >&2; usage; exit 1;;
  esac
done

echo "${REPO_PATH@A}"
echo "${TEST_IMAGE_NAME@A}"
echo "${NO_BUILD@A}"
echo "${DOCKER_WORKDIR@A}"
echo "${CLEANUP@A}"

buildcontainer () {
  if ! ${NO_BUILD}; then
    echo "==========================================================="
    echo "Building Container ${TEST_IMAGE_NAME}"
    echo "==========================================================="
    docker build . -t ${TEST_IMAGE_NAME}
  fi
}

runcontainerlilypond () {
  echo "==========================================================="
  echo "Running the container ${TEST_IMAGE_NAME}"
  echo "run lilypond on score "
  echo "==========================================================="
  docker run \
    --mount type=bind,src="${REPO_PATH}",dst=${DOCKER_WORKDIR} \
    ${TEST_IMAGE_NAME} \
    /bin/sh -c "cd ${DOCKER_WORKDIR}/testfiles/ \
       && lilypond TestScore.ly"
}

runcontainertimidity () {
  echo "==========================================================="
  echo "Running the container ${TEST_IMAGE_NAME}"
  echo "transforming .midi files from previous stage to .mp3"
  echo "==========================================================="
  docker run \
    --mount type=bind,src="${REPO_PATH}",dst=${DOCKER_WORKDIR} \
    ${TEST_IMAGE_NAME} \
    /bin/sh -c "cd ${DOCKER_WORKDIR}/testfiles/ \
       && timidity TestScore.midi -Ow -o - | lame - -b 64 TestScore.mp3"
}

runcontainerlatex () {
  echo "==========================================================="
  echo "Running the container ${TEST_IMAGE_NAME}"
  echo "Provied LaTeX book with embedded music"
  echo "==========================================================="
  docker run \
    --mount type=bind,src="${REPO_PATH}",dst=${DOCKER_WORKDIR} \
    ${TEST_IMAGE_NAME} \
    /bin/sh -c "cd ${DOCKER_WORKDIR}/testfiles/ \
       && latexmk -shell-escape -pdflatex=lualatex -pdf *.tex"
}

cleanupcontainer () {
  if ${CLEANUP}; then
    echo "==========================================================="
    echo "Cleaning Up containers"
    echo "==========================================================="
    docker image rm --force "${TEST_IMAGE_NAME}"
  fi
}

buildcontainer
runcontainerlilypond
runcontainertimidity
runcontainerlatex
cleanupcontainer



