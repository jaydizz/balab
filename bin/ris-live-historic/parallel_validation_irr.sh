#!/bin/bash

find /mount/storage/stash/historic/irr | grep irrv4.storable | xargs -L 1 -P 5 -I % bash -c './mrt_validator_irr.pl %' | tee /mount/storage/stash/historic/stats/hist_irr_validation.txt
