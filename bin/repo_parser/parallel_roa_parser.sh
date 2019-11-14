find /mount/storage/db/rpki/old | egrep  '2019_[0-9]+_[0-9]+-00' | sort -n | uniq | xargs -L 1 -P 5 -I % bash -c './roa_parser.pl %'
