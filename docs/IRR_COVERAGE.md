# Understanding what implicit, direct and less-specific coverage mean.

Consider the following example:

```
route:   10.0.0.0/8
origin:  AS100

route:   10.1.0.0/20
origin:  AS200

route:   10.0.0.0/24
origin:  AS300
```

If an announcement of the prefix `10.1.0.0/20` is received from the origin `AS200`, a route object _directly_ covers this announcement. It is therefore _valid_.

If an announcement of the prefix `10.1.0.0/24` is received from the origin `AS200`, a route object that is less-specific covers this announcement. It is therefore _valid\_less\_specific_.

If an announcement of the prefix `10.0.0.0/24` is received from the origin `AS100`, a direct lookup for a route object fails, since the origin AS mismatches. However, since there is an route-object for the less specific /8 with a correct origin, we say that the announcement is _implicitely_ covered. 

