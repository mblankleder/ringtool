ringtool
========

Re-formats the nodetool output to resolve the node name instead of the ip address using Dynect managed DNS

## Approach ##
The idea is to execute the nodetool command and substitute the ip address of each node by the hostname

## Possibilities ##
* resolving using dynect dns
* get everything from the Chef server

## Needs ##
* dynect dns
* cassandra 1.1.x
* ruby

## Provides ##
* resolves the ip address and shows the node hostname instead 

```
$ nodetool -h nodename.yourdomain.com ring keyspace_name
```

## Troubleshooting ##
* check the env file

