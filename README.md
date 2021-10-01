# webmark

benchmarking utility for web servers with postgres, in docker


## usage

to run all the tests:

```sh
./run-all
```

this will create a file called "result.html" with the output!

to run tests for a specific configuration:

```sh
./run-configuration go-fiber
```

or to run only a single test

```sh
./run-test go-fiber helloworld
```

## configuration

there is a list of environment variables that can be set in the `config` file.

## running against a remote docker host

to run against a remote docker, set it in your `DOCKER_HOST` and `WEBMARK_URL` environment variables, for example:

```sh
export DOCKER_HOST=ssh://10.0.0.1
export WEBMARK_URL=http://10.0.0.1:3000/
./run-all
```


## running load test from a separate docker host

the load test will normally be run from the local machine, but you can specify a remote host with the `LOAD_DOCKER_HOST` environment variable:

```sh
export DOCKER_HOST=ssh://10.0.0.1
export LOAD_DOCKER_HOST=ssh://10.0.0.2
export LOAD_TARGET=http://10.0.0.1:3000/ # this should be accessible from LOAD_DOCKER_HOST
./run-all
```


## postgres database

the postgres database can also be started on a specific docker host:

```sh
export WEBMARKDB_DOCKER_HOST=ssh://10.0.0.3
export WEBMARKDB_CONNECT="webmarkdb:10.0.0.3" # this should be accessible from DOCKER_HOST
./run-all
```

to run against a postgres database that's outside of docker, make sure the docker containers can access it with the default credentials (at host webmarkdb) and set the `WEBMARKDB_OFF` environment variable to 1.

```sh
export WEBMARKDB_OFF=1
export WEBMARKDB_CONNECT="webmarkdb:10.0.0.3" # this should be accessible from DOCKER_HOST
./run-all
```


## working on a configuration

to make changes to a configuration it can be helpful to have the postgres database running locally:

```sh
./start-database
```

this will build and start the database listening to 5432 on localhost and as webmarkdb in the 'webmark' docker network.

to run one of the configurations you can tell it to join that network:

```sh
cd configurations/go-fiber
docker build --tag testing .
docker run --network webmark --publish 3000:3000 testing
```


## adding a configuration

to add a configuration, add a new folder in 'configurations' with a Dockerfile.

the server should run on port 3000, and connect to a postgres instance at postgres://postgres:webmark@webmarkdb:5432/postgres


## adding a test

there is one line per test in the 'tests' file.

it is expected that the servers listen to GET-requests to each url listed in that file.


## digitalocean setup

there's a script to create a digitalocean droplet and run the tests on it.

you need to have `jq` and `doctl` installed and configured, then run:

```sh
./utils/digitalocean-setup          # create digitalocean droplet and config file
source ./utils/digitalocean-config  # import the environment variables needed to connect
./run-all                           # run all the tests on the remote machine
./utils/digitalocean-destroy        # destroy the digitalocean droplet
```

note that it will include all ssh keys from your digitalocean account on the machine.

it's set up to use a fairly expensive droplet so make sure you don't forget to delete it!

you can use ./utiles-digitalocean-setup-3 to create separate
test runner, database and application server droplets:

```sh
./utils/digitalocean-setup-3        # create digitalocean droplets and config file
source ./utils/digitalocean-config  # import the environment variables needed to connect
./run-all                           # run all the tests on the remote machine
./utils/digitalocean-destroy        # destroy the digitalocean droplets
```

this is likely overkill, so unless there's a specific reason just use the single droplet.
