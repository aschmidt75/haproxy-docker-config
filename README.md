haproxy-docker-config
=====================

Automatically configure haproxy to balance between docker instances, allowing easy shifting of containers.


##What##
A docker container usually exports a public-facing port on the local interface of the host. To allow external clients to access the container, a balancing solution such as haproxy takes place on the host. haproxy-docker-config uses libaugeas to rewrite the haproxy configuration file on-the-fly, according to container details after looking them up from the docker api. Basic modifications are allowed, such as 
  * taking new containers into balancing, 
  * taking them out of balancing, 
  * checking whether container are balanced and 
  * verifying that all containers within the haproxy configuration are running.
haproxy can be restarted or hot-restarted.

##Why##
Docker containers can be brought up and taken down with virtually no effort, so a balancing solution has to be in close sync to the container state. haproxy-docker-config helps maintaining this state and serves as a basis for further dynamic balancing solutions.


##How##
First, open haproxy.cfg and create a listener with your desired settings. Create exactly one server entry as a comment, use ERB-style variables to render ip and port information into it. proxy-docker-config uses libaugeas to open the augeas resource /files/etc/haproxy/haproxy.cfg and will use the comment line to create new server entries by rendering it with details
```
listen  dockerha-app1   0.0.0.0:8380
        balance         roundrobin
        #DOCKERSERVER   <%= id %> <%= ip %>:<%= port %> check inter 2000 rise 2 fall 5
```
Use the listener name as input to -l/--listen parameter, as in the above example, dockerha-app1. Use container ids of running containers as input to the --add, --delete, --check parameters. proxy-docker-config will take the container id and query container details from the docker API, such as the public facing port, to render the comment line above. 
It is able to 
  * restart haproxy by calling the System V init scripts 
  * hot-restart haproxy by using the -sf option of haproxy (see /usr/share/doc/haproxy/haproxy-en.txt.gz, 2.4.1 Hot reconfiguration)


##Examples##
Given this docker state
```
# docker ps
ID                  IMAGE                                 COMMAND              CREATED             STATUS              PORTS
caee75cbf7b5        aschmidt75/centos-node-hello:latest   node /src/index.js   About an hour ago   Up About an hour    49161->8080
597215a9450b        aschmidt75/centos-node-hello:latest   node /src/index.js   About an hour ago   Up About an hour    49160->8080
a32198606724        aschmidt75/centos-node-hello:latest   node /src/index.js   About an hour ago   Up About an hour    49159->8080
f2cc6e975169        aschmidt75/centos-node-hello:latest   node /src/index.js   About an hour ago   Up About an hour    49158->8080
```

Take the first 3 servers into balancing and restart haproxy. Use listener dockerha-app1
```
# ./haproxy-docker-config.rb -l dockerha-app1 --add caee75cbf7b5,597215a9450b,a32198606724 --restart
caee75cbf7b5            balanced        127.0.0.1:49161
597215a9450b            balanced        127.0.0.1:49160
a32198606724            balanced        127.0.0.1:49159
 * Restarting haproxy haproxy
   ...done.
```

See if servers are balanced
```
# ./haproxy-docker-config.rb -l dockerha-app1 -c 
caee75cbf7b5            balanced
597215a9450b            balanced
a32198606724            balanced
```

See what servers are not balanced (the 4th one)
```
# ./haproxy-docker-config.rb -l dockerha-app1 -c f2cc6e975169
f2cc6e975169            not_balanced
```

Take servers out of balancing, show balancing members. Do not restart.
```
# ./haproxy-docker-config.rb -l dockerha-app1 --delete a32198606724 --show
caee75cbf7b5 127.0.0.1:49161 check inter 2000 rise 2 fall 5
597215a9450b 127.0.0.1:49160 check inter 2000 rise 2 fall 5
```

See if all containers in haproxy balancing are running. Kill one, see again.
```
# ./haproxy-docker-config.rb -l dockerha-app1 --verify
caee75cbf7b5            found
597215a9450b            found

# docker kill 597215a9450b
597215a9450b

# ./haproxy-docker-config.rb -l dockerha-app1 --verify
caee75cbf7b5            found
597215a9450b            not_found
```

##Dependencies##
As a dependency, you'll need
 * The [docker-client](https://github.com/geku/docker-client)
 * libaugeas and libaugeas-ruby

Of course it does not make much sense without
 * [Docker](http://www.docker.io/)
 * [haproxy](http://haproxy.1wt.eu/)


##How##
proxy-docker-config uses libaugeas to open the augeas resource /files/etc/haproxy/haproxy.cfg. 
First, open haproxy.cfg and create a listener with your desired settings. Create exactly one server entry as a comment, use ERB-style variables to render ip and port information into it. proxy-docker-config will use this line to create new server entries:
```
listen  dockerha-app1   0.0.0.0:8380
        balance         roundrobin
        #DOCKERSERVER   <%= id %> <%= ip %>:<%= port %> check inter 2000 rise 2 fall 5
```
Use the listener name given above as input to -l/--listen parameter.


```
Usage: haproxy-docker-config [options]
        --help                       Show help details
    -l, --listen LISTENER            Perform actions on LISTENER listen service. Mandatory
    -a ID1[:PORT][,ID2[:PORT],...],  Add one or more containers (identified by docker container id) with optional private port number. Public-facing port will be looked up.
        --add
    -d, --delete ID1[,ID2,...]       Delete one or more containers (identified by docker container id) from balancing
    -c, --check [ID1,ID2,...]        Check if given containers (identified by docker container id) are balanced by given listener. Return list of all balanced containers if no id give
        --verify                     Check if all server entries in given listener are backed by a running container.
    -r, --restart                    Restart haproxy after modifying config. (must have rights to, assumes service haproxy configured)
    -h, --hot-restart [pidfile]      Hot Restart haproxy after modifying config. Default pidfile=/var/run/haproxy.pid
    -v, --verbose                    Be verbose about what i do.
    -s, --show                       show target servers of given listener.
        --yaml                       Output as yaml.
        --json                       Output as json.
  ```

##Todo##
  * make docker base url configurable/parameterize
  * implement alternativ rewrite solution, parallel to libaugeas
  * gem
  * select container by tags of images

##License##
This is OPEN SOURCE, see LICENSE.txt for details.

