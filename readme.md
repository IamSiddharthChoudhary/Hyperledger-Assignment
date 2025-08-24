# Hyperledger Fabric Assignment - Complete Implementation

## Overview

This project implements a complete Hyperledger Fabric network with an Asset Transfer System featuring Attribute-Based Access Control (ABAC). The implementation includes a smart contract (chaincode), REST API, and comprehensive testing suite.

```
fabric-assignment/
├── network/
│   ├── crypto-config.yaml          # Crypto material configuration
│   ├── configtx.yaml              # Channel configuration
│   ├── connection-org1.json       # Fabric SDK connection profile
│   ├── crypto-config/             # Generated cryptographic materials
│   ├── channel-artifacts/         # Channel configuration files
│   └── docker/                    # Docker compose files
│       ├── docker-compose-ca.yaml
│       ├── docker-compose-network.yaml
│       └── peer-base.yaml
├── chaincode/
│   └── asset-transfer/
│       ├── asset-transfer.go      # Main chaincode with ABAC
│       ├── go.mod
│       └── go.sum
├── api/
│   ├── app.js                     # REST API server
│   ├── package.json               # Node.js dependencies
│   ├── enrollAdmin.js             # Admin enrollment script
│   └── registerUser.js            # User registration script
├── scripts/
│   ├── setup.sh                   # Complete setup automation
│   ├── network.sh                 # Network management
│   ├── deploy-chaincode.sh        # Chaincode deployment
│   └── test-api.sh               # API testing script
├── wallet/                        # User identities wallet
└── README.md                      # This file
```

## Features Implemented

### ✅ Network Components

- **2 Organizations** (Org1, Org2)
- **4 Peers** (2 per organization)
- **1 Orderer** with Raft consensus
- **1 Channel** (mychannel)
- **Fabric CA** for identity management

### ✅ ABAC (Attribute-Based Access Control)

- **Admin Role**: Can create, read, update, delete any asset
- **Auditor Role**: Can view all assets but cannot modify
- **User Role**: Can only view and update their own assets

### ✅ Chaincode Functions

- `CreateAsset(assetID, owner, value)` - Admin only
- `ReadAsset(assetID)` - Role-based access
- `UpdateAsset(assetID, newValue)` - Owner and admin only
- `DeleteAsset(assetID)` - Admin only
- `GetAllAssets()` - Auditor and admin only
- `GetMyAssets()` - Returns user's own assets

### ✅ REST API Endpoints

- `POST /assets` - Create asset
- `GET /assets/{id}` - Get asset by ID
- `PUT /assets/{id}` - Update asset
- `DELETE /assets/{id}` - Delete asset
- `GET /assets` - Get assets (all or user's own)
- `GET /health` - Health check
- `GET /user-info` - Get user role information

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Go 1.19+
- Node.js 16+
- Hyperledger Fabric binaries (peer, orderer, configtxgen, cryptogen)

### Option 1: Automated Setup (Recommended)

```bash
# Clone or create the project directory
mkdir fabric-assignment && cd fabric-assignment

# Copy all the provided files to appropriate directories
# (crypto-config.yaml, configtx.yaml, etc.)

# Make setup script executable and run complete setup
chmod +x scripts/setup.sh
./scripts/setup.sh full
```

### Option 2: Manual Step-by-Step Setup

#### Step 1: Generate Cryptographic Materials

```bash
cryptogen generate --config=./crypto-config.yaml
```

#### Step 2: Generate Channel Artifacts

```bash
export FABRIC_CFG_PATH=$(pwd)
mkdir -p network/channel-artifacts

# Generate genesis block
configtxgen -profile SampleMultiNodeEtcdRaft -channelID system-channel -outputBlock ./network/channel-artifacts/genesis.block

# Generate channel transaction
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./network/channel-artifacts/channel.tx -channelID mychannel

# Generate anchor peer transactions
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./network/channel-artifacts/Org1MSPanchors.tx -channelID mychannel -asOrg Org1MSP
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./network/channel-artifacts/Org2MSPanchors.tx -channelID mychannel -asOrg Org2MSP
```

#### Step 3: Start the Network

```bash
chmod +x scripts/network.sh
./scripts/network.sh up
```

#### Step 4: Deploy Chaincode

```bash
chmod +x scripts/deploy-chaincode.sh
./scripts/deploy-chaincode.sh deploy
```

#### Step 5: Setup API Users

```bash
cd api
npm install
node enrollAdmin.js
node registerUser.js
```

#### Step 6: Start API

```bash
npm start
```

## Usage Examples

### Using CLI Commands

#### Create Asset (Admin only)

```bash
docker exec cli peer chaincode invoke \
    -o orderer.example.com:7050 \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
    -C mychannel -n asset-transfer \
    --peerAddresses peer0.org1.example.com:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
    -c '{"function":"CreateAsset","Args":["asset1","owner1","1000"]}'
```

#### Query Asset

```bash
docker exec cli peer chaincode query \
    -C mychannel -n asset-transfer \
    -c '{"function":"ReadAsset","Args":["asset1"]}'
```

### Using REST API

#### Health Check

```bash
curl http://localhost:3000/health
```

#### Create Asset (Admin)

```bash
curl -X POST http://localhost:3000/assets \
  -H "Content-Type: application/json" \
  -d '{"id":"asset123","owner":"user1","value":500}'
```

#### Get Asset

```bash
curl "http://localhost:3000/assets/asset123?userRole=admin"
```

#### Update Asset

```bash
curl -X PUT http://localhost:3000/assets/asset123 \
  -H "Content-Type: application/json" \
  -d '{"value":750,"userRole":"admin"}'
```

#### Get All Assets (Auditor only)

```bash
curl "http://localhost:3000/assets?userRole=auditor&all=true"
```

#### Delete Asset (Admin only)

```bash
curl -X DELETE http://localhost:3000/assets/asset123
```

## Testing

### Automated Testing

```bash
# Test the API
chmod +x scripts/test-api.sh
./scripts/test-api.sh
```

### Manual Testing

1. Start the API: `cd api && npm start`
2. Open another terminal
3. Run the test script: `./scripts/test-api.sh`

## Access Control Rules

| Role    | Create Assets | View All Assets | View Own Assets | Update Own Assets | Update Any Asset | Delete Assets |
| ------- | ------------- | --------------- | --------------- | ----------------- | ---------------- | ------------- |
| Admin   | ✅            | ✅              | ✅              | ✅                | ✅               | ✅            |
| Auditor | ❌            | ✅              | ✅              | ✅                | ❌               | ❌            |
| User    | ❌            | ❌              | ✅              | ✅                | ❌               | ❌            |

## Network Management

### Start Network

```bash
./scripts/network.sh up
```

### Stop Network

```bash
./scripts/network.sh down
```

### Clean Everything

```bash
./scripts/network.sh clean
# or
./scripts/setup.sh clean
```

### Verify Network Status

```bash
./scripts/network.sh verify
```

## Troubleshooting

### Common Issues

1. **"configtxgen: command not found"**

   - Install Hyperledger Fabric binaries
   - Add to PATH: `export PATH=/path/to/fabric/bin:$PATH`

2. **"ABAC access denied"**

   - Check user role attributes in certificates
   - Ensure proper user enrollment with correct attributes

3. **"Network connection refused"**

   - Verify all containers are running: `docker ps`
   - Check container logs: `docker logs <container-name>`

4. **"API connection error"**
   - Ensure network is running
   - Check connection profile certificates
   - Verify wallet contains user identities

### Logs

```bash
# View container logs
docker logs orderer.example.com
docker logs peer0.org1.example.com
docker logs cli

# View API logs
cd api && npm start
```

## Architecture Details

### Network Topology

```
┌─────────────────┐    ┌─────────────────┐
│   Organization 1 │    │   Organization 2 │
│                 │    │                 │
│  ┌─────────────┐│    │┌─────────────┐  │
│  │   Peer0     ││    ││   Peer0     │  │
│  │  :7051      ││    ││   :9051     │  │
│  └─────────────┘│    │└─────────────┘  │
│  ┌─────────────┐│    │┌─────────────┐  │
│  │   Peer1     ││    ││   Peer1     │  │
│  │  :8051      ││    ││   :10051    │  │
│  └─────────────┘│    │└─────────────┘  │
│                 │    │                 │
│  ┌─────────────┐│    │┌─────────────┐  │
│  │ Fabric CA   ││    ││ Fabric CA   │  │
│  │  :7054      ││    ││   :8054     │  │
│  └─────────────┘│    │└─────────────┘  │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     │
            ┌─────────────────┐
            │    Orderer      │
            │    :7050        │
            │  (Raft Solo)    │
            └─────────────────┘
```

### Components Interaction

1. **Client Application** → **REST API** → **Fabric Gateway**
2. **Fabric Gateway** → **Peer Nodes** → **Chaincode**
3. **Peer Nodes** → **Orderer** → **Block Creation**
4. **Blocks** → **Distributed Ledger** → **State Updates**

## Security Features

1. **TLS Communication** - All network communication encrypted
2. **MSP-based Identity** - Cryptographic identity management
3. **Attribute-based Access** - Role-based permissions in chaincode
4. **Channel Isolation** - Private communication between organizations
5. **Endorsement Policies** - Multi-signature transaction validation

## Performance Considerations

- **Endorsement Policy**: Requires majority endorsement
- **Block Size**: Configured for optimal throughput
- **Timeout Settings**: Balanced for reliability and speed
- **Connection Pooling**: API uses persistent connections

## Production Deployment Notes

For production deployment, consider:

1. **High Availability**: Multiple orderers with Raft consensus
2. **Monitoring**: Implement logging and metrics collection
3. **Backup**: Regular backup of peer ledger data
4. **Security**: Hardware Security Modules (HSM) for key management
5. **Scaling**: Load balancing for API endpoints
6. **Governance**: Proper chaincode lifecycle management

## Assignment Completion Checklist

- ✅ Network setup (2 orgs, 2 peers each, 1 orderer, 1 channel)
- ✅ Fabric CA configuration and identity management
- ✅ ABAC policies implementation (admin, auditor, user roles)
- ✅ Chaincode development with all required functions
- ✅ Chaincode deployment and testing
- ✅ REST API with all specified endpoints
- ✅ Complete automation scripts
- ✅ Comprehensive testing suite
- ✅ Documentation and usage examples

## License

This project is for educational purposes as part of a Hyperledger Fabric assignment.

---

**Note**: This implementation demonstrates enterprise blockchain concepts and should be adapted for specific production requirements.
