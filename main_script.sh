#!/bin/bash
# HI!

export FABRIC_CFG_PATH=$PWD
export PATH=$PWD:${PWD}/../bin:$PATH
export VERBOSE=false

#Check validity of the script command
function checkFlags() {
    if [ $g_flag -eq 0 ]; then
        echo 
        echo "Provide flag \"-g <Genesis block profile>\""
        echo "Use ./script.sh -h for to see the available options"
        echo
        exit 1
    fi

    if [ $c_flag -eq 0 ]; then
        echo 
        echo "Provide flag \"-c <Channel profile>\""
        echo "Use ./script.sh -h for to see the available options"
        echo
        exit 1
    fi

    if [ $a_flag -eq 0 ]; then
        echo 
        echo "Provide one or more flags \"-a <Anchor peer org MSP>\""
        echo "Use ./script.sh -h for to see the available options"
        echo
        exit 1
    fi

    if [ $n_flag -eq 0 ]; then
        echo 
        echo "Provide flag \"-n <Channel Name>\""
        echo "Use ./script.sh -h for to see the available options"
        echo
        exit 1
    fi

    if [ $s_flag -eq 0 ]; then
        echo 
        echo "Provide one or more flags \"-s <System Channel Name>\""
        echo "Use ./script.sh -h for to see the available options"
        echo
        exit 1
    fi

    if [ $d_flag -eq 0 ]; then
        echo 
        echo "Provide one or more flags \"-d <Docker Files>\""
        echo "Use ./script.sh -h for to see the available options"
        echo
        exit 1
    fi
}

#Asking if we want to clear all existing docker containers,volumes,networks,artifacts
function askProceed() {
    echo "This will delete all existing docker containers,volumes,networks,artifacts"
    read -p "Do you want to continue? (y/n):" proceed
    case "$proceed" in
    y | Y | "")
        echo -n "Deleting"
        for i in 1 2 3 4
        do
            sleep 1
            echo -n "."
        done
        echo
        deleteAll
        ;;
    n | N)
        echo "Exiting"
        exit 1
        ;;
    *)
        echo "Invalid"
        askProceed
        ;;
    esac
}

function deleteAll() {
    echo "----------Deleting containers----------"
    docker rm -f $(docker ps -aq)
    echo "----------Deleting volumes-------------"
    docker volume rm $(docker volume ls)
    echo "----------Deleting networks------------"
    docker network rm $(docker network ls)
    rm -Rf channel-artifacts
    if [ $? -eq 0 ]; then
        echo
        echo
        echo "----------Deleting artifacts-----------"
        echo "Removed dir: ./channel-artifacts"
    fi
    echo
}

function setPeerVariables() {
    BASE_DIR=$PWD/crypto-config/peerOrganizations
    cd $BASE_DIR

    #Create a list of all the organizations
    ORG_LIST=$(ls)


    #Create a list of all the peers and index them by organizations
    PEER_LIST_BOUNDARIES+=(0)
    for i in $ORG_LIST
    do
        cd $BASE_DIR/${i}/peers
        PEER_LIST_BOUNDARIES+=(${PEER_LIST_BOUNDARIES[-1]})
        for j in $(ls)
        do
            PEER_LIST+=(${j})
            PEER_LIST_BOUNDARIES[-1]=`expr ${PEER_LIST_BOUNDARIES[-1]} + 1`
        done
    done

    #Export private keys of the CA's of each org
    k=1
    for i in $ORG_LIST
    do
        cd $BASE_DIR/${i}/ca
        export CA${k}_PRIVATE_KEY=$(ls *_sk)
        k=`expr $k + 1`
    done
    echo "Exported private keys of each organization as \"CA<org-number>_PRIVATE_KEY\""

    #Export listening ports of each peer - from docker-compose-base.yaml
    cd $FABRIC_CFG_PATH/base
    for i in ${PEER_LIST[@]}
    do
        PEER_PORT_LIST+=($(grep "CORE_PEER_ADDRESS=$i" ./docker-compose-base.yaml | sed -ne "s/- CORE_PEER_ADDRESS=${i}://p" ))
    done

    cd $FABRIC_CFG_PATH
    #declare -A ANCHOR_PEER_BOOLEAN
    for i in ${PEER_LIST[@]}
    do
        sudo cat ./configtx.yaml | yq r - Organizations[].AnchorPeers[].Host | grep -e "$i"
        if [ $? -eq 0 ]; then
            ANCHOR_PEER_BOOLEAN+=(1)
        else
            ANCHOR_PEER_BOOLEAN+=(0)
        fi
        #echo ${ANCHOR_PEER_BOOLEAN[$i]}
    done
    echo ${ANCHOR_PEER_BOOLEAN[@]}
}

function getMSPID() {
    k=0 #counter
    cd $FABRIC_CFG_PATH
    for i in ${ORG_LIST[@]}
    do
        #Find the msp id for one peer of each org from the docker compose file
        j=${PEER_LIST[${PEER_LIST_BOUNDARIES[$k]}]} #One peer taken from an organization
        ORG_MSP_LIST+=($(grep -e "\- CORE_PEER_ID=" -e "\- CORE_PEER_LOCALMSPID" ./base/docker-compose-base.yaml | sed -ne "s/- CORE_PEER_ID=//p" -e "s/- CORE_PEER_LOCALMSPID=//p" | tr '\n' '=' | tr -d ' ' | sed 's/=/\n/2;P;D' | grep -e "${j}" | sed -ne "s/${j}=//p"))
        k=`expr $k + 1`
    done
}

BLACKLISTED_VERSIONS="^1\.0\. ^1\.1\.0-preview ^1\.1\.0-alpha"

function checkPrereqs() {
  # Note, we check configtxlator externally because it does not require a config file, and peer in the
  # docker image because of FAB-8551 that makes configtxlator return 'development version' in docker
  LOCAL_VERSION=$(configtxlator version | sed -ne 's/ Version: //p')
  DOCKER_IMAGE_VERSION=$(docker run --rm hyperledger/fabric-tools:$IMAGETAG peer version | sed -ne 's/ Version: //p' | head -1)

  echo "LOCAL_VERSION=$LOCAL_VERSION"
  echo "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

  if [ "$LOCAL_VERSION" != "$DOCKER_IMAGE_VERSION" ]; then
    echo "=================== WARNING ==================="
    echo "  Local fabric binaries and docker images are  "
    echo "  out of  sync. This may cause problems.       "
    echo "==============================================="
  fi

  for UNSUPPORTED_VERSION in $BLACKLISTED_VERSIONS; do
    echo "$LOCAL_VERSION" | grep -q $UNSUPPORTED_VERSION
    if [ $? -eq 0 ]; then
      echo "ERROR! Local Fabric binary version of $LOCAL_VERSION does not match this newer version of BYFN and is unsupported. Either move to a later version of Fabric or checkout an earlier version of fabric-samples."
      exit 1
    fi

    echo "$DOCKER_IMAGE_VERSION" | grep -q $UNSUPPORTED_VERSION
    if [ $? -eq 0 ]; then
      echo "ERROR! Fabric Docker image version of $DOCKER_IMAGE_VERSION does not match this newer version of BYFN and is unsupported. Either move to a later version of Fabric or checkout an earlier version of fabric-samples."
      exit 1
    fi
  done
}

#Generate Certificates
function generateCerts() { 
    echo
    echo
    echo "-----------------------------------------------------------------"
    echo "-------------------- Generating certificates --------------------"
    echo "-----------------------------------------------------------------"
    echo
    
    #Check if cryptogen exists
    which cryptogen
    if [ "$?" -ne 0 ]; then
        echo "Cryptogen tool not found. Exiting..."
        exit 1
    fi

    #Check if certificates have already been generated
    if [ -d crypto-config ]
    then
        echo "Deleting existing certificates"
        rm -Rf crypto-config
    fi 

    #Generating certificates
    set -x
    cryptogen generate --config=./crypto-config.yaml
    res=$?
    set +x
    if [ $res -ne 0 ]
    then
        echo "Failed to generate certificates..."
        exit 1
    fi
    echo
    echo
}

function generateArtifacts() {
    echo
    echo
    echo "------------------------------------------------------------"
    echo "----------------- Generating Genesis Block -----------------"
    echo "------------------------------------------------------------"
    echo

    sudo chmod a+rwx $PWD
    
    #Checking if configtxgen tool is present
    which configtxgen
    if [ "$?" -ne 0 ]; then
        echo "Configtxgen tool not found. Exiting..."
        exit 1
    fi

    mkdir channel-artifacts

    set -x
    configtxgen -profile $GENESIS_BLOCK_PROFILE -channelID $SYS_CHANNEL -outputBlock ./channel-artifacts/genesis.block
    set +x
    if [ $? -ne 0 ]
    then
        echo "Failed to create genesis block..."
        exit 1
    fi
    

    echo
    echo
    echo
    echo
    echo "------------------------------------------------------------"
    echo "------------------ Generating Channel Txn ------------------"
    echo "------------------------------------------------------------"
    echo
    echo

    set -x
    configtxgen -profile $CHANNEL_PROFILE -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME
    set +x
    if [ $? -ne 0 ]
    then
        echo "Failed to create channel transaction..."
        exit 1
    fi

    for i in "${ANCHOR_PEER_MSP_LIST[@]}"
    do
        #echo hellooo
        echo
        echo
        echo
        echo "------------------------------------------------------------"
        echo "------ Generating Anchor Peers Update:$i------"
        echo "------------------------------------------------------------"
        echo
        echo

        set -x
        configtxgen -profile $CHANNEL_PROFILE -outputAnchorPeersUpdate ./channel-artifacts/${i}Anchors.tx -channelID $CHANNEL_NAME -asOrg ${i}
        set +x
        if [ $? -ne 0 ]
        then
            echo "Failed to update anchor peer $i..."
            exit 1
        fi
    done
}

function displayChannelCreate() {
    echo
    echo
    echo "------------------------------------------------------------"
    echo "---------------------- Create channel ----------------------"
    echo "------------------------------------------------------------"
    echo
    echo
}

function promptChannelCreation() {
    #Read from user
    echo "Select the peer to create channel with: "
    k=1
    for i in ${PEER_LIST[@]}
    do
        echo "$k) $i"
        k=`expr $k + 1`
    done
    read -p "Enter choice: " choice

    if [ $choice -gt 0 -a $choice -le ${PEER_LIST_BOUNDARIES[-1]} ]; then
        echo "Setting environment variables"
    else
        promptChannelCreation
    fi
}


function networkStart() {
    #Execute required functions in sequence
    checkPrereqs
    checkFlags
    askProceed
    generateCerts
    generateArtifacts
    setPeerVariables

    #Get MSP ID's of all orgs
    getMSPID

    #Bring up the containers
    cd $FABRIC_CFG_PATH
    docker-compose ${DOCKER_FILES} up -d

    #List all the containers
    docker ps -a

    # echo ${ORG_LIST[@]}
    # echo ${ORG_MSP_LIST[@]}
    # echo ${PEER_LIST[@]}
    # echo ${PEER_LIST_BOUNDARIES[@]}
    # echo ${PEER_PORT_LIST[@]}
    
    export x=${ORG_MSP_LIST[@]}
    # echo ${x[@]}

    #Channel requirements
    displayChannelCreate
    promptChannelCreation

    docker exec cli scripts/new_script.sh ${ORG_LIST[@]} "." ${ORG_MSP_LIST[@]} "." ${PEER_LIST[@]} "." ${PEER_LIST_BOUNDARIES[@]} "." ${PEER_PORT_LIST[@]} "." $choice $CHANNEL_NAME ${ANCHOR_PEER_BOOLEAN[@]} "."
}

export IMAGETAG="latest"

g_flag=0
c_flag=0
a_flag=0
n_flag=0
s_flag=0
d_flag=0

while getopts "g:c:a:n:s:d:" opt; do
    case "$opt" in
    g)
        g_flag=1
        GENESIS_BLOCK_PROFILE=$OPTARG
        ;;
    c)
        c_flag=1
        CHANNEL_PROFILE=$OPTARG
        ;;
    a)
        a_flag=1
        ANCHOR_PEER_MSP_LIST+=("$OPTARG")
        ;;
    n)
        n_flag=1
        export CHANNEL_NAME=$OPTARG
        ;;
    s)
        s_flag=1
        export SYS_CHANNEL=$OPTARG
        ;;
    d)
        d_flag=1
        DOCKER_FILES="${DOCKER_FILES} -f ${OPTARG}"
        ;;
    esac
done


# checkFlags
# askProceed
# generateCerts
# generateArtifacts
# setPeerVariables

networkStart