#!/bin/bash

find /mount/storage/stash/historic/ | grep rpkiv4.storable | awk 'NR % 1 == 0' | xargs -L 1 -P 10 -I % bash -c './rpki_prefix_sizes.pl %' | tee /mount/storage/stash/historic/stats/avg_roa_prefix_sizes.txt
