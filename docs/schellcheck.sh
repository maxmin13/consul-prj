#!/bin/bash

find . -type f -name "*.sh" -exec "shellcheck" "--format=gcc" {} \; > temp/schellcheck.txt
