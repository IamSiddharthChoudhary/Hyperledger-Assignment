#!/bin/bash

set -e

echo "=== Simplified Identity Setup ==="

# Ensure crypto materials exist
cd network
if [ ! -d "crypto-config/peerOrganizations" ]; then
    echo "Generating crypto materials..."
    cryptogen generate --config=./crypto-config.yaml
fi
cd ..

echo "✅ Crypto materials ready"

echo ""
echo "Available identities for your assignment:"
echo "  Org1 Admin: network/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/"
echo "  Org1 User:  network/crypto-config/peerOrganizations/org1.example.com/users/User1@org1.example.com/"
echo "  Org2 Admin: network/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/"
echo "  Org2 User:  network/crypto-config/peerOrganizations/org2.example.com/users/User1@org2.example.com/"

echo ""
echo "These identities are sufficient for your assignment!"
echo "You can implement role-based access control in your chaincode."