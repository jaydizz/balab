#!/bin/bash

find /mount/storage/stash/historic/irr | grep irrv4.storable | xargs -L 1 -P 5 -I % bash -c './find_conflicts.pl %' | tee /mount/storage/stash/historic/stats/repo_compare/general_stats
