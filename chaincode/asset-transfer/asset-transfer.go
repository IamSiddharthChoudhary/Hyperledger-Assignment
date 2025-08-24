package main

import (
    "encoding/json"
    "fmt"
    "log"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SmartContract struct {
    contractapi.Contract
}

type Asset struct {
    ID             string `json:"ID"`
    Owner          string `json:"owner"`
    Value          int    `json:"value"`
    CreatedBy      string `json:"createdBy"`
}

func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *SmartContract) CreateAsset(ctx contractapi.TransactionContextInterface, id string, owner string, value int) error {
    // Get transaction creator
    creator, err := ctx.GetClientIdentity().GetID()
    if err != nil {
        return fmt.Errorf("failed to get client identity: %v", err)
    }

    // Check if user has admin role
    role, found, err := ctx.GetClientIdentity().GetAttributeValue("role")
    if err != nil {
        return fmt.Errorf("failed to get role attribute: %v", err)
    }
    
    if !found || role != "admin" {
        return fmt.Errorf("only admin can create assets")
    }

    exists, err := s.AssetExists(ctx, id)
    if err != nil {
        return err
    }
    if exists {
        return fmt.Errorf("the asset %s already exists", id)
    }

    asset := Asset{
        ID:        id,
        Owner:     owner,
        Value:     value,
        CreatedBy: creator,
    }
    
    assetJSON, err := json.Marshal(asset)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(id, assetJSON)
}

func (s *SmartContract) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
    // Get user role and identity
    role, found, err := ctx.GetClientIdentity().GetAttributeValue("role")
    if err != nil {
        return nil, fmt.Errorf("failed to get role attribute: %v", err)
    }
    
    if !found {
        return nil, fmt.Errorf("role attribute not found")
    }

    assetJSON, err := ctx.GetStub().GetState(id)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("the asset %s does not exist", id)
    }

    var asset Asset
    err = json.Unmarshal(assetJSON, &asset)
    if err != nil {
        return nil, err
    }

    // Access control: Auditors can view all, regular users only their own
    if role == "auditor" {
        return &asset, nil
    } else if role == "user" {
        clientID, err := ctx.GetClientIdentity().GetID()
        if err != nil {
            return nil, fmt.Errorf("failed to get client identity: %v", err)
        }
        
        if asset.Owner != clientID {
            return nil, fmt.Errorf("access denied: you can only view your own assets")
        }
    }

    return &asset, nil
}

func (s *SmartContract) UpdateAsset(ctx contractapi.TransactionContextInterface, id string, newValue int) error {
    // Check if user has admin role
    role, found, err := ctx.GetClientIdentity().GetAttributeValue("role")
    if err != nil {
        return fmt.Errorf("failed to get role attribute: %v", err)
    }
    
    if !found || role != "admin" {
        return fmt.Errorf("only admin can update assets")
    }

    exists, err := s.AssetExists(ctx, id)
    if err != nil {
        return err
    }
    if !exists {
        return fmt.Errorf("the asset %s does not exist", id)
    }

    asset, err := s.ReadAssetInternal(ctx, id)
    if err != nil {
        return err
    }

    asset.Value = newValue

    assetJSON, err := json.Marshal(asset)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(id, assetJSON)
}

func (s *SmartContract) DeleteAsset(ctx contractapi.TransactionContextInterface, id string) error {
    // Check if user has admin role
    role, found, err := ctx.GetClientIdentity().GetAttributeValue("role")
    if err != nil {
        return fmt.Errorf("failed to get role attribute: %v", err)
    }
    
    if !found || role != "admin" {
        return fmt.Errorf("only admin can delete assets")
    }

    exists, err := s.AssetExists(ctx, id)
    if err != nil {
        return err
    }
    if !exists {
        return fmt.Errorf("the asset %s does not exist", id)
    }

    return ctx.GetStub().DelState(id)
}

func (s *SmartContract) GetAllAssets(ctx contractapi.TransactionContextInterface) ([]*Asset, error) {
    // Check if user has auditor role
    role, found, err := ctx.GetClientIdentity().GetAttributeValue("role")
    if err != nil {
        return nil, fmt.Errorf("failed to get role attribute: %v", err)
    }
    
    if !found || role != "auditor" {
        return nil, fmt.Errorf("only auditors can view all assets")
    }

    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()

    var assets []*Asset
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }

        var asset Asset
        err = json.Unmarshal(queryResponse.Value, &asset)
        if err != nil {
            return nil, err
        }
        assets = append(assets, &asset)
    }

    return assets, nil
}

func (s *SmartContract) AssetExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
    assetJSON, err := ctx.GetStub().GetState(id)
    if err != nil {
        return false, fmt.Errorf("failed to read from world state: %v", err)
    }

    return assetJSON != nil, nil
}

func (s *SmartContract) ReadAssetInternal(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
    assetJSON, err := ctx.GetStub().GetState(id)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("the asset %s does not exist", id)
    }

    var asset Asset
    err = json.Unmarshal(assetJSON, &asset)
    if err != nil {
        return nil, err
    }

    return &asset, nil
}

func main() {
    assetChaincode, err := contractapi.NewChaincode(&SmartContract{})
    if err != nil {
        log.Panicf("Error creating asset-transfer chaincode: %v", err)
    }

    if err := assetChaincode.Start(); err != nil {
        log.Panicf("Error starting asset-transfer chaincode: %v", err)
    }
}