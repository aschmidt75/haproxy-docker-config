haproxy-docker-config
=====================

Configuring haproxy to automatically redirect to docker instances


```
docker-haproxy-config  

	-l,--listen app1				# specify listener. Mandatory

	-a,--add ID1,ID2,ID3[:PORT],...			# add docker container (by instance id) to balancing. Optional port

	-d,--delete ID1,ID2,...				# remove docker containers from balancing

	-c,--check ID1,ID2,...				# check if docker containers are balanced

	-r,--restart					# if something was modified, gracefully restart haproxy

    -v,--verbose
  ```
