# Datastructures used by this Tool

## Patricia Trie

To efficiently store and lookup IP-Adresses and prefixes, they are stored in a TRIE-datastructure. The Patricia Trie is a binary prefix-tree, that performs fast lookups. 
When checking for the validity of a route, a lookup in this trie is performed. If no match is found, _undef_ is returned. Upon a match, a hashref is returned. 

## Userdata Hashref

The hasref mentioned above is of the following format:

```
$userdata => {
  prefix => "prefix that was parsed in ROA/ro",
  
  #These are used for sorting in Luke_filewalker and are never cleared. Might be useful
  base_n => "Baseaddress of prefix in network representation.",
  base_p => "Baseaddress in human readable notation",
  last_n => "Last address of prefix in network representation",
  last_p => "Last address of prefix in humand readable notation",
  version => AF\_INET || AF\_INETv6,

  #List of origin_AS that are directly covering a prefix. See below
  origin => {
     "ASX" = 1,
     "ASy" = 1,
     ...
  }
  
  #List of origin_AS that cover the prefix implicitely. See below
  less_specific => {
    "ASZ" = 1,
    ...
  }
}
```

To understand what covering and implicitely covering means, see IRR\_COVERAGE.md


