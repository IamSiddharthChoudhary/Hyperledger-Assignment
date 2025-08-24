#!/bin/bash

export PATH=${PWD}/bin:$PATH
export FABRIC_CFG_PATH=${PWD}/network

function networkUp() {
    echo "Creating Docker network..."
    docker network create fabric_test 2>/dev/null || true
    
    echo "Starting network containers..."
    cd network/docker
    docker-compose -f docker-compose-network.yaml up -d
    cd ../..
    
    echo "Waiting for containers to start..."
    sleep 10
}

function createChannel() {
    echo "Creating channel 'mychannel'..."
    
    docker exec cli peer channel create \
        -o orderer.example.com:7050 \
        -c mychannel \
        -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/channel.tx \
        --outputBlock /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/mychannel.block \
        --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
}

function joinChannel() {
    echo "Joining peers to channel..."
    
    # Join peer0.org1 to channel
    docker exec cli peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/mychannel.block
    
    # Join peer1.org1 to channel
    docker exec -e CORE_PEER_ADDRESS=peer1.org1.example.com:8051 cli peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/mychannel.block
    
    # Switch to Org2 and join peers
    docker exec -e CORE_PEER_LOCALMSPID=Org2MSP \
        -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
        -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp \
        -e CORE_PEER_ADDRESS=peer0.org2.example.com:9051 \
        cli peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/mychannel.block
    
    # Join peer1.org2 to channel
    docker exec -e CORE_PEER_LOCALMSPID=Org2MSP \
        -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls/ca.crt \
        -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp \
        -e CORE_PEER_ADDRESS=peer1.org2.example.com:10051 \
        cli peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/mychannel.block
}

# Execute functions
networkUp
createChannel
joinChannel

echo "Network setup complete!"
echo "Verify with: docker ps"