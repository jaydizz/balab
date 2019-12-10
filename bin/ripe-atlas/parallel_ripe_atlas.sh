#!/bin/bash

cat ./measurments | xargs -L 1 -P 5 -I % bash -c './measurement_parser.pl %' 
