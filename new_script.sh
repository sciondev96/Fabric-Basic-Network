#!/bin/bash

#Form arrays for all the variables passed as parameters
function getExports() {
    while [ $1 != "." ]
    do
        ORG_LIST+=($1)
        shift
    done

    shift

    while [ $1 != "." ]
    do
        ORG_MSP_LIST+=($1)
        shift
    done

    shift

    while [ $1 != "." ]
    do
        PEER_LIST+=($1)
        shift
    done

    shift

    while [ $1 != "." ]
    do
        PEER_LIST_BOUNDARIES+=($1)
        shift
    done

    shift

    while [ $1 != "." ]
    do
        PEER_PORT_LIST+=($1)
        shift
    done

    shift

    choice=$1
    shift

    CHANNEL_NAME=$1
    shift

    while [ $1 != "." ]
    do
        ANCHOR_PEER_BOOLEAN+=($1)
        shift
    done

    shift
}

function setEnvVariables() {
    #Find org and peer indices
    peer_index=`expr $1 - 1`
    org_index=0
    for i in ${PEER_LIST_BOUNDARIES[@]:1}
    do
        if [ $peer_index -lt $i ]; then
            break
        fi
        export org_index=`expr $org_index + 1`
    done
    #echo "$peer_index $org_index"

    #Set the required environment variables
    CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG_LIST[$org_index]}/users/Admin@${ORG_LIST[$org_index]}/msp
    CORE_PEER_ADDRESS=${PEER_LIST[$peer_index]}:${PEER_PORT_LIST[$peer_index]}
    CORE_PEER_LOCALMSPID="${ORG_MSP_LIST[$org_index]}"
    CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG_LIST[$org_index]}/peers/${PEER_LIST[$peer_index]}/tls/ca.crt
    
    echo "CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS"
    echo "CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID"
    echo "CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH"
    echo "CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE"
}

function createChannel() {
    #Set the environment variables for the peer with which we set channel up
    echo
    echo
    setEnvVariables $choice

    #Channel Creation
    peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
}

function joinPeers() {
    #Loop through the peers and join each one to the channel
    k=1
    while [ $k -le ${PEER_LIST_BOUNDARIES[-1]} ]
    do
        setEnvVariables $k
        peer channel join -b  $CHANNEL_NAME.block
        k=`expr $k + 1`
        #sleep 15
    done
}

function updateAnchorPeers() {
    k=0
    for i in ${PEER_LIST[@]}
    do
        if [ ${ANCHOR_PEER_BOOLEAN[$k]} -eq 1 ]; then
            setEnvVariables `expr $k + 1`
            peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${ORG_MSP_LIST[${org_index}]}Anchors.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
        fi
        k=`expr $k + 1`
    done
}





getExports $@

createChannel
joinPeers
updateAnchorPeers

# setEnvVariables 4