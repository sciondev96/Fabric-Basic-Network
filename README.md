# fabric-basic-network
A basic fabric network based on the build your first network of fabric samples with 4 organizations.

Each organization has 2 peers each and each peer has its own CouchDB container. The ordering service is RAFT made of 5 orderer nodes.

To bring up the network:

COMPOSE_PROJECT_NAME=<project_name> COMPOSE_HTTP_TIMEOUT=300  docker-compose -f docker-compose-cli.yaml -f docker-compose-couch.yaml -f docker-compose-etcdraft2.yaml up

To bring down the network:

COMPOSE_PROJECT_NAME=<project_name> COMPOSE_HTTP_TIMEOUT=300  docker-compose -f docker-compose-cli.yaml -f docker-compose-couch.yaml -f docker-compose-etcdraft2.yaml down
