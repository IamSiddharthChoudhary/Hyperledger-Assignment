#!/bin/bash

echo "=== Verifying Fabric CA Setup ==="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

echo "✅ Docker is running"

# Check if network exists
if docker network ls | grep -q fabric_test; then
    echo "✅ Docker network 'fabric_test' exists"
else
    echo "⚠️  Docker network 'fabric_test' doesn't exist. Creating it..."
    docker network create fabric_test
fi

# Check CA containers
echo ""
echo "Checking CA container status..."
CA_ORG1_STATUS=$(docker inspect ca_org1 --format='{{.State.Status}}' 2>/dev/null || echo "not found")
CA_ORG2_STATUS=$(docker inspect ca_org2 --format='{{.State.Status}}' 2>/dev/null || echo "not found")

if [ "$CA_ORG1_STATUS" = "running" ]; then
    echo "✅ ca_org1 is running"
else
    echo "❌ ca_org1 is $CA_ORG1_STATUS"
fi

if [ "$CA_ORG2_STATUS" = "running" ]; then
    echo "✅ ca_org2 is running"
else
    echo "❌ ca_org2 is $CA_ORG2_STATUS"
fi

# Check if CA endpoints are responding
echo ""
echo "Testing CA endpoints..."

# Test CA Org1
if curl -k --connect-timeout 5 https://localhost:7054/cainfo > /dev/null 2>&1; then
    echo "✅ CA Org1 (port 7054) is responding"
else
    echo "❌ CA Org1 (port 7054) is not responding"
fi

# Test CA Org2
if curl -k --connect-timeout 5 https://localhost:8054/cainfo > /dev/null 2>&1; then
    echo "✅ CA Org2 (port 8054) is responding"
else
    echo "❌ CA Org2 (port 8054) is not responding"
fi

# Check if crypto-config directory exists and has CA certificates
echo ""
echo "Checking crypto-config structure..."

ORG1_CA_DIR="network/crypto-config/peerOrganizations/org1.example.com/ca"
ORG2_CA_DIR="network/crypto-config/peerOrganizations/org2.example.com/ca"

if [ -d "$ORG1_CA_DIR" ] && [ -n "$(ls -A $ORG1_CA_DIR)" ]; then
    echo "✅ Org1 CA directory exists and has certificates"
    echo "   Files: $(ls $ORG1_CA_DIR)"
else
    echo "❌ Org1 CA directory is missing or empty"
    echo "   You may need to run: cryptogen generate --config=./network/crypto-config.yaml"
fi

if [ -d "$ORG2_CA_DIR" ] && [ -n "$(ls -A $ORG2_CA_DIR)" ]; then
    echo "✅ Org2 CA directory exists and has certificates"
    echo "   Files: $(ls $ORG2_CA_DIR)"
else
    echo "❌ Org2 CA directory is missing or empty"
    echo "   You may need to run: cryptogen generate --config=./network/crypto-config.yaml"
fi

# Check Fabric CA client
echo ""
echo "Checking Fabric CA client..."
if command -v fabric-ca-client > /dev/null 2>&1; then
    echo "✅ fabric-ca-client is installed"
    echo "   Version: $(fabric-ca-client version)"
else
    echo "❌ fabric-ca-client is not installed or not in PATH"
fi

echo ""
echo "=== Setup Verification Complete ==="

# Provide recommendations
if [ "$CA_ORG1_STATUS" != "running" ] || [ "$CA_ORG2_STATUS" != "running" ]; then
    echo ""
    echo "🔧 To start CA containers:"
    echo "   cd network/docker"
    echo "   docker-compose -f docker-compose-ca.yaml up -d"
fi

if [ ! -d "$ORG1_CA_DIR" ] || [ ! -d "$ORG2_CA_DIR" ]; then
    echo ""
    echo "🔧 To generate crypto materials:"
    echo "   cd network"
    echo "   cryptogen generate --config=./crypto-config.yaml"
fi