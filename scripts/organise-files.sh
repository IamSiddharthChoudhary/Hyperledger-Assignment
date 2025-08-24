#!/bin/bash


echo "=== Organizing Hyperledger Fabric Assignment Files ==="

echo "Creating directory structure..."
mkdir -p {network,chaincode/asset-transfer,api,scripts,wallet}
mkdir -p network/{crypto-config,channel-artifacts,docker}

echo "Directory structure created!"

create_file() {
    local filepath=$1
    local content=$2
    
    echo "Creating $filepath..."
    echo "$content" > "$filepath"
}

echo "Making scripts executable..."
chmod +x scripts/*.sh 2>/dev/null || true

echo "=== Next Steps ==="
echo "1. Copy the provided configuration files to their respective directories:"
echo "   - crypto-config.yaml → project root"
echo "   - configtx.yaml → project root" 
echo "   - asset-transfer.go → chaincode/asset-transfer/"
echo "   - Docker compose files → network/docker/"
echo "   - API files → api/"
echo "   - Scripts → scripts/"
echo ""
echo "2. Run the complete setup:"
echo "   ./scripts/setup.sh full"
echo ""
echo "3. Or run individual components:"
echo "   ./scripts/setup.sh prereq    # Check prerequisites"
echo "   ./scripts/setup.sh crypto    # Generate crypto materials"
echo "   ./scripts/setup.sh artifacts # Generate channel artifacts"
echo "   ./scripts/setup.sh network   # Start network"
echo "   ./scripts/setup.sh chaincode # Deploy chaincode"
echo "   ./scripts/setup.sh api       # Setup API"
echo "   ./scripts/setup.sh test      # Test system"
echo ""
echo "4. Test the API:"
echo "   ./scripts/test-api.sh"
echo ""
echo "=== File Organization Complete ==="