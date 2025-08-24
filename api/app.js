const express = require("express");
const { Gateway, Wallets } = require("fabric-network");
const path = require("path");
const fs = require("fs");
const cors = require("cors");

const app = express();
const port = 3000;

// Middleware
app.use(express.json());
app.use(cors());

// Configuration
const channelName = "mychannel";
const chaincodeName = "asset-transfer";

// Connection profile and wallet paths
const ccpPath = path.resolve(
  __dirname,
  "..",
  "network",
  "connection-org1.json"
);
const walletPath = path.join(process.cwd(), "wallet");

// Helper function to get contract
async function getContract(userRole = "admin") {
  try {
    // Load connection profile
    const ccp = JSON.parse(fs.readFileSync(ccpPath, "utf8"));

    // Create a new file system based wallet
    const wallet = await Wallets.newFileSystemWallet(walletPath);

    // Check to see if user identity exists in wallet
    const identity = await wallet.get(userRole);
    if (!identity) {
      throw new Error(
        `An identity for the user "${userRole}" does not exist in the wallet`
      );
    }

    // Create a new gateway for connecting to peer node
    const gateway = new Gateway();
    await gateway.connect(ccp, {
      wallet,
      identity: userRole,
      discovery: { enabled: true, asLocalhost: true },
    });

    // Get the network (channel) contract
    const network = await gateway.getNetwork(channelName);
    const contract = network.getContract(chaincodeName);

    return { contract, gateway };
  } catch (error) {
    console.error("Error getting contract:", error);
    throw error;
  }
}

// Helper function to handle errors
function handleError(res, error, message = "Internal server error") {
  console.error(error);
  res.status(500).json({
    error: message,
    details: error.message,
  });
}

// POST /assets - Creates an asset
app.post("/assets", async (req, res) => {
  try {
    const { id, owner, value } = req.body;

    if (!id || !owner || value === undefined) {
      return res.status(400).json({
        error: "Missing required fields: id, owner, value",
      });
    }

    const { contract, gateway } = await getContract("admin");

    await contract.submitTransaction(
      "CreateAsset",
      id,
      owner,
      value.toString()
    );
    await gateway.disconnect();

    res.status(201).json({
      message: "Asset created successfully",
      assetId: id,
    });
  } catch (error) {
    handleError(res, error, "Failed to create asset");
  }
});

// GET /assets/:id - Retrieves asset details
app.get("/assets/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { userRole = "user" } = req.query;

    const { contract, gateway } = await getContract(userRole);

    const result = await contract.evaluateTransaction("ReadAsset", id);
    await gateway.disconnect();

    const asset = JSON.parse(result.toString());
    res.json(asset);
  } catch (error) {
    if (error.message.includes("does not exist")) {
      res.status(404).json({ error: "Asset not found" });
    } else if (error.message.includes("access denied")) {
      res.status(403).json({ error: "Access denied" });
    } else {
      handleError(res, error, "Failed to retrieve asset");
    }
  }
});

// GET /assets - Get all assets (for auditors) or user's assets
app.get("/assets", async (req, res) => {
  try {
    const { userRole = "user", all = "false" } = req.query;

    const { contract, gateway } = await getContract(userRole);

    let result;
    if (all === "true" && (userRole === "auditor" || userRole === "admin")) {
      result = await contract.evaluateTransaction("GetAllAssets");
    } else {
      result = await contract.evaluateTransaction("GetMyAssets");
    }

    await gateway.disconnect();

    const assets = JSON.parse(result.toString());
    res.json(assets);
  } catch (error) {
    if (error.message.includes("access denied")) {
      res.status(403).json({ error: "Access denied" });
    } else {
      handleError(res, error, "Failed to retrieve assets");
    }
  }
});

// PUT /assets/:id - Updates an asset
app.put("/assets/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { value, userRole = "user" } = req.body;

    if (value === undefined) {
      return res.status(400).json({
        error: "Missing required field: value",
      });
    }

    const { contract, gateway } = await getContract(userRole);

    await contract.submitTransaction("UpdateAsset", id, value.toString());
    await gateway.disconnect();

    res.json({
      message: "Asset updated successfully",
      assetId: id,
    });
  } catch (error) {
    if (error.message.includes("does not exist")) {
      res.status(404).json({ error: "Asset not found" });
    } else if (error.message.includes("access denied")) {
      res.status(403).json({ error: "Access denied" });
    } else {
      handleError(res, error, "Failed to update asset");
    }
  }
});

// DELETE /assets/:id - Deletes an asset
app.delete("/assets/:id", async (req, res) => {
  try {
    const { id } = req.params;

    const { contract, gateway } = await getContract("admin");

    await contract.submitTransaction("DeleteAsset", id);
    await gateway.disconnect();

    res.json({
      message: "Asset deleted successfully",
      assetId: id,
    });
  } catch (error) {
    if (error.message.includes("does not exist")) {
      res.status(404).json({ error: "Asset not found" });
    } else {
      handleError(res, error, "Failed to delete asset");
    }
  }
});

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    service: "Hyperledger Fabric Asset Transfer API",
  });
});

// Get user info endpoint
app.get("/user-info", async (req, res) => {
  try {
    const { userRole = "user" } = req.query;

    const { contract, gateway } = await getContract(userRole);

    // This would typically get user information from the chaincode
    await gateway.disconnect();

    res.json({
      role: userRole,
      permissions: {
        createAsset: userRole === "admin",
        viewAllAssets: userRole === "auditor" || userRole === "admin",
        viewOwnAssets: true,
        updateOwnAssets: true,
        deleteAsset: userRole === "admin",
      },
    });
  } catch (error) {
    handleError(res, error, "Failed to get user info");
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    error: "Something went wrong!",
    details: err.message,
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: "Endpoint not found",
  });
});

app.listen(port, () => {
  console.log(`Asset Transfer API running on http://localhost:${port}`);
  console.log("Available endpoints:");
  console.log("  POST   /assets           - Create asset (admin only)");
  console.log("  GET    /assets/:id       - Get asset by ID");
  console.log(
    "  GET    /assets           - Get all assets (auditor) or user assets"
  );
  console.log("  PUT    /assets/:id       - Update asset");
  console.log("  DELETE /assets/:id       - Delete asset (admin only)");
  console.log("  GET    /health           - Health check");
  console.log("  GET    /user-info        - Get user permissions");
});
