#!/bin/bash

# Complete setup script for Hyperledger Fabric Assignment
set -e

echo "=== Hyperledger Fabric Assignment Setup ==="

# Function to check prerequisites
checkPrerequisites() {
    echo "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo "Error: Docker Compose is not installed"
        exit 1
    fi
    
    # Check Go
    if ! command -v go &> /dev/null; then
        echo "Error: Go is not installed"
        exit 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        echo "Error: Node.js is not installed"
        exit 1
    fi
    
    # Check Fabric binaries
    if ! command -v peer &> /dev/null; then
        echo "Warning: Fabric binaries not found in PATH"
        echo "Please ensure Fabric binaries are installed and in PATH"
    fi
    
    echo "Prerequisites check completed!"
}

# Function to setup project structure
setupProject() {
    echo "Setting up project structure..."
    
    # Create directories
    mkdir -p network/{crypto-config,channel-artifacts,docker}
    mkdir -p chaincode/asset-transfer
    mkdir -p api
    mkdir -p scripts
    mkdir -p wallet
    
    echo "Project structure created!"
}

# Function to generate crypto materials
generateCrypto() {
    echo "Generating cryptographic materials..."
    
    cd network
    if [ ! -d "crypto-config" ] || [ -z "$(ls -A crypto-config)" ]; then
        cryptogen generate --config=../crypto-config.yaml
        echo "Crypto materials generated!"
    else
        echo "Crypto materials already exist!"
    fi
    cd ..
}

# Function to generate channel artifacts
generateChannelArtifacts() {
    echo "Generating channel artifacts..."
    
    cd network
    export FABRIC_CFG_PATH=$(pwd)/..
    
    # Create channel artifacts directory
    mkdir -p channel-artifacts
    
    # Generate genesis block
    configtxgen -profile SampleMultiNodeEtcdRaft -channelID system-channel -outputBlock ./channel-artifacts/genesis.block
    
    # Generate channel configuration transaction
    configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID mychannel
    
    # Generate anchor peer transactions
    configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID mychannel -asOrg Org1MSP
    configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID mychannel -asOrg Org2MSP
    
    cd ..
    echo "Channel artifacts generated!"
}

# Function to setup chaincode
setupChaincode() {
    echo "Setting up chaincode..."
    
    cd chaincode/asset-transfer
    
    # Initialize Go module if not exists
    if [ ! -f go.mod ]; then
        go mod init asset-transfer
        go mod tidy
        echo "Go module initialized for chaincode!"
    fi
    
    cd ../..
}

# Function to setup API
setupAPI() {
    echo "Setting up Node.js API..."
    
    cd api
    
    # Install dependencies if package.json exists
    if [ -f package.json ]; then
        npm install
        echo "API dependencies installed!"
    else
        echo "package.json not found in api directory"
    fi
    
    cd ..
}

# Function to create connection profile with actual certificates
createConnectionProfile() {
    echo "Creating connection profile with actual certificates..."
    
    # Check if crypto materials exist
    if [ ! -d "network/crypto-config" ]; then
        echo "Error: Crypto materials not found. Run generateCrypto first."
        return 1
    fi
    
    # Extract CA certificates
    PEER0_CA_CERT=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' network/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt)
    PEER1_CA_CERT=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' network/crypto-config/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt)
    CA_CERT=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' network/crypto-config/peerOrganizations/org1.example.com/ca/ca.org1.example.com-cert.pem)
    
    # Create connection profile with actual certificates
    cat > network/connection-org1.json <<EOF
{
    "name": "test-network-org1",
    "version": "1.0.0",
    "client": {
        "organization": "Org1",
        "connection": {
            "timeout": {
                "peer": {
                    "endorser": "300"
                }
            }
        }
    },
    "organizations": {
        "Org1": {
            "mspid": "Org1MSP",
            "peers": [
                "peer0.org1.example.com",
                "peer1.org1.example.com"
            ],
            "certificateAuthorities": [
                "ca.org1.example.com"
            ]
        }
    },
    "peers": {
        "peer0.org1.example.com": {
            "url": "grpcs://localhost:7051",
            "tlsCACerts": {
                "pem": "${PEER0_CA_CERT}"
            },
            "grpcOptions": {
                "ssl-target-name-override": "peer0.org1.example.com",
                "hostnameOverride": "peer0.org1.example.com"
            }
        },
        "peer1.org1.example.com": {
            "url": "grpcs://localhost:8051",
            "tlsCACerts": {
                "pem": "${PEER1_CA_CERT}"
            },
            "grpcOptions": {
                "ssl-target-name-override": "peer1.org1.example.com",
                "hostnameOverride": "peer1.org1.example.com"
            }
        }
    },
    "certificateAuthorities": {
        "ca.org1.example.com": {
            "url": "https://localhost:7054",
            "caName": "ca-org1",
            "tlsCACerts": {
                "pem": "${CA_CERT}"
            },
            "httpOptions": {
                "verify": false
            }
        }
    }
}
EOF
    
    echo "Connection profile created with actual certificates!"
}

# Function to start the network
startNetwork() {
    echo "Starting Hyperledger Fabric network..."
    
    # Make network script executable
    chmod +x scripts/network.sh
    
    # Start the network
    ./scripts/network.sh up
    
    echo "Network started successfully!"
}

# Function to deploy chaincode
deployChaincode() {
    echo "Deploying chaincode..."
    
    # Make chaincode script executable
    chmod +x scripts/deploy-chaincode.sh
    
    # Deploy chaincode
    ./scripts/deploy-chaincode.sh deploy
    
    echo "Chaincode deployed successfully!"
}

# Function to setup API users
setupAPIUsers() {
    echo "Setting up API users..."
    
    cd api
    
    # Enroll admin
    node enrollAdmin.js
    
    # Register users
    node registerUser.js
    
    cd ..
    
    echo "API users setup completed!"
}

# Function to test the system
testSystem() {
    echo "Testing the system..."
    
    # Test chaincode directly
    echo "Testing chaincode..."
    ./scripts/deploy-chaincode.sh test
    
    # Start API in background for testing
    echo "Starting API for testing..."
    cd api
    npm start &
    API_PID=$!
    cd ..
    
    # Wait for API to start
    sleep 5
    
    # Test API endpoints
    echo "Testing API endpoints..."
    
    # Health check
    curl -X GET http://localhost:3000/health
    echo ""
    
    # Create asset (as admin)
    curl -X POST http://localhost:3000/assets \
        -H "Content-Type: application/json" \
        -d '{"id":"test-asset","owner":"testuser","value":1000}' \
        -w "\nStatus: %{http_code}\n"
    
    # Get asset
    curl -X GET "http://localhost:3000/assets/test-asset?userRole=admin" \
        -w "\nStatus: %{http_code}\n"
    
    # Stop API
    kill $API_PID 2>/dev/null || true
    
    echo "System testing completed!"
}

# Main execution based on arguments
case "$1" in
    "full")
        checkPrerequisites
        setupProject
        generateCrypto
        generateChannelArtifacts
        setupChaincode
        setupAPI
        createConnectionProfile
        startNetwork
        deployChaincode
        setupAPIUsers
        testSystem
        echo "=== Setup completed successfully! ==="
        echo "You can now:"
        echo "1. Start the API: cd api && npm start"
        echo "2. Test endpoints at http://localhost:3000"
        echo "3. Use the REST API to interact with the blockchain"
        ;;
    "prereq")
        checkPrerequisites
        ;;
    "crypto")
        generateCrypto
        ;;
    "artifacts")
        generateChannelArtifacts
        ;;
    "network")
        startNetwork
        ;;
    "chaincode")
        deployChaincode
        ;;
    "api")
        setupAPI
        setupAPIUsers
        ;;
    "test")
        testSystem
        ;;
    "clean")
        echo "Cleaning up..."
        ./scripts/network.sh down
        docker system prune -af
        docker volume prune -f
        rm -rf wallet/*
        echo "Cleanup completed!"
        ;;
    *)
        echo "Usage: $0 {full|prereq|crypto|artifacts|network|chaincode|api|test|clean}"
        echo "  full      - Complete setup (recommended for first time)"
        echo "  prereq    - Check prerequisites only"
        echo "  crypto    - Generate crypto materials only"
        echo "  artifacts - Generate channel artifacts only"
        echo "  network   - Start network only"
        echo "  chaincode - Deploy chaincode only"
        echo "  api       - Setup API and users only"
        echo "  test      - Test the system only"
        echo "  clean     - Clean up everything"
        exit 1
        ;;
esac