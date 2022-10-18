#!/bin/bash

cd "${PROJECT_ROOT}" || exit
find . -type f -name "*.sh" -exec "shellcheck" "--format=gcc" {} \; > temp/schellcheck.txt
