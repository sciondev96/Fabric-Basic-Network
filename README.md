# fabric-basic-network
A basic fabric network based on the build your first network of fabric samples with 4 organizations.

Each organization has 2 peers each and each peer has its own CouchDB container. The ordering service is RAFT made of 5 orderer nodes.

To bring up the network:

COMPOSE_PROJECT_NAME=<project_name> COMPOSE_HTTP_TIMEOUT=300  docker-compose -f docker-compose-cli.yaml -f docker-compose-couch.yaml -f docker-compose-etcdraft2.yaml up

Then, enter into docker cli container, to create channels, install chaincodes and to query the chaincode

docker exec cli -it bin/bash

Follow the byfn tutorial at https://hyperledger-fabric.readthedocs.io/en/release-1.4/build_network.html 

To access the couchDB data, http://localhost:5984/_utils/ 

To bring down the network:

COMPOSE_PROJECT_NAME=<project_name> COMPOSE_HTTP_TIMEOUT=300  docker-compose -f docker-compose-cli.yaml -f docker-compose-couch.yaml -f docker-compose-etcdraft2.yaml down
