#!/bin/bash

echo "=== Hyperledger Fabric CA Troubleshooting ==="

echo "1. Checking Docker status..."
docker --version
docker-compose --version

echo ""
echo "2. Checking running containers..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "3. Checking CA container details..."
if docker ps | grep -q ca_org1; then
    echo "✅ ca_org1 is running"
    echo "Org1 CA logs (last 5 lines):"
    docker logs ca_org1 --tail 5
else
    echo "❌ ca_org1 is not running"
fi

echo ""
if docker ps | grep -q ca_org2; then
    echo "✅ ca_org2 is running"
    echo "Org2 CA logs (last 5 lines):"
    docker logs ca_org2 --tail 5
else
    echo "❌ ca_org2 is not running"
fi

echo ""
echo "4. Testing CA endpoints..."
echo "Testing CA Org1:"
curl -k -s https://localhost:7054/cainfo || echo "Failed to connect"

echo ""
echo "Testing CA Org2:"
curl -k -s https://localhost:8054/cainfo || echo "Failed to connect"

echo ""
echo "5. Checking crypto-config structure..."
echo "Org1 identities:"
ls -la network/crypto-config/peerOrganizations/org1.example.com/users/ 2>/dev/null || echo "Not found"

echo "Org2 identities:"
ls -la network/crypto-config/peerOrganizations/org2.example.com/users/ 2>/dev/null || echo "Not found"

echo ""
echo "=== Troubleshooting Complete ==="