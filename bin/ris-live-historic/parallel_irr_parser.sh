find /mount/storage/db/irr/old | egrep -o '2019_[0-9]+_[0-9]+-00' | sort -n | uniq | xargs -L 1 -P 10 -I % bash -c './parse_irrs.pl %' 
