#!/bin/bash
CI_COMMIT_TAG="v2.8.9-lts"

if [[ "$CI_COMMIT_TAG" =~ ^v(([0-9]+\.[0-9]+)\.[0-9]+)(.*)$ ]];
then
  echo ${BASH_REMATCH[1]} ;
  echo ${BASH_REMATCH[2]} ;
  echo ${BASH_REMATCH[3]:1} ;
  echo ${BASH_REMATCH[2]}${BASH_REMATCH[3]} ;
else
  echo "Not proper format";
fi
