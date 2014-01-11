ringtool
========

Re-formats the nodetool output to resolve the node DNS name on Dynect 

## Needs ##
** dynect dns
** cassandra 1.1.x
** ruby

## Provides ##
** resolves the ip address and shows the node name instead 

```
$ nodetool -h nodename.yourdomain.com ring keyspace_name
```

## Troubleshooting ##
** check the env file

