#!/bin/bash

find /mount/storage/stash/historic/ | grep rpkiv4.storable | awk 'NR % 1 == 0' | xargs -L 1 -P 10 -I % bash -c './mrt_validator.pl %' | tee /mount/storage/stash/historic/stats/hist_rpki_validation.txt
