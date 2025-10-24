#!/usr/bin/env node
import { spawnSync } from "child_process";
import { config } from "dotenv";
import { join, dirname } from "path";
import { readFileSync } from "fs";
import { parse } from "toml";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
config();

// Get all arguments after the script name
const args = process.argv.slice(2);
let fileName = "DeployHabitChain.s.sol";
let network = "baseSepolia";

// Show help message if --help is provided
if (args.includes("--help") || args.includes("-h")) {
  console.log(`
Usage: pnpm deploy:pk [options]

This script deploys contracts using a private key from the DEPLOYER_PRIVATE_KEY environment variable.
It's designed for CI/CD and production deployments to testnets.

Options:
  --file <filename>     Specify the deployment script file (default: DeployHabitChain.s.sol)
  --network <network>   Specify the network (default: baseSepolia)
  --help, -h            Show this help message

Environment Variables:
  DEPLOYER_PRIVATE_KEY  Your private key (without 0x prefix) - REQUIRED

Examples:
  DEPLOYER_PRIVATE_KEY=abc123... pnpm deploy:pk
  DEPLOYER_PRIVATE_KEY=abc123... pnpm deploy:pk --network base
  pnpm deploy:pk --file DeployHabitChain.s.sol --network baseSepolia

Note: Make sure your DEPLOYER_PRIVATE_KEY is set in your .env file or environment.
      NEVER commit your .env file with real private keys!
  `);
  process.exit(0);
}

// Parse arguments
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--network" && args[i + 1]) {
    network = args[i + 1];
    i++;
  } else if (args[i] === "--file" && args[i + 1]) {
    fileName = args[i + 1];
    i++;
  }
}

// Check if private key is set
if (!process.env.DEPLOYER_PRIVATE_KEY) {
  console.error(`
❌ Error: DEPLOYER_PRIVATE_KEY environment variable is not set!

To deploy to ${network}, you need to set your private key in the environment:

1. Create a .env file in packages/foundry/ (if it doesn't exist)
2. Add this line (without the 0x prefix):
   DEPLOYER_PRIVATE_KEY=your_private_key_here

3. Make sure .env is in .gitignore (it should be by default)

4. Run the deployment again:
   pnpm deploy:pk --network ${network}

⚠️  WARNING: Never commit your private key to git!
  `);
  process.exit(1);
}

// Validate private key format (basic check)
const privateKey = process.env.DEPLOYER_PRIVATE_KEY.replace(/^0x/, "");
if (!/^[0-9a-fA-F]{64}$/.test(privateKey)) {
  console.error(`
❌ Error: Invalid private key format!

Your DEPLOYER_PRIVATE_KEY should be:
- 64 hexadecimal characters
- Without 0x prefix (or with it, we'll handle both)
- Example: abc123def456... (64 chars total)
  `);
  process.exit(1);
}

// Check if the network exists in rpc_endpoints
try {
  const foundryTomlPath = join(__dirname, "..", "foundry.toml");
  const tomlString = readFileSync(foundryTomlPath, "utf-8");
  const parsedToml = parse(tomlString);

  if (!parsedToml.rpc_endpoints[network]) {
    console.log(
      `\n❌ Error: Network '${network}' not found in foundry.toml!`,
      "\nPlease check foundry.toml for available networks in the [rpc_endpoints] section."
    );
    process.exit(1);
  }
} catch (error) {
  console.error("\n❌ Error reading or parsing foundry.toml:", error);
  process.exit(1);
}

console.log(`
🚀 Deploying ${fileName} to ${network}...
📝 Using private key from DEPLOYER_PRIVATE_KEY environment variable
`);

// Build the forge script command with private key
const deployScript = `script/${fileName}`;
const forgeCommand = [
  "script",
  deployScript,
  "--rpc-url",
  network,
  "--private-key",
  privateKey,
  "--broadcast",
  "--legacy",
  "--ffi",
];

// Run forge script
console.log(
  "Running: forge " +
    forgeCommand.filter((arg) => arg !== privateKey).join(" ") +
    " --private-key [HIDDEN]"
);
const deployResult = spawnSync("forge", forgeCommand, {
  stdio: "inherit",
  shell: true,
  cwd: join(__dirname, ".."),
});

if (deployResult.status !== 0) {
  console.error("\n❌ Deployment failed!");
  process.exit(deployResult.status);
}

console.log("\n✅ Deployment successful!");
console.log("📝 Generating TypeScript ABIs...");

// Generate ABIs
const abiResult = spawnSync("node", ["scripts-js/generateTsAbis.js"], {
  stdio: "inherit",
  shell: true,
  cwd: join(__dirname, ".."),
});

if (abiResult.status !== 0) {
  console.error(
    "\n⚠️  Warning: ABI generation failed, but deployment was successful"
  );
  process.exit(abiResult.status);
}

console.log(`
✅ All done!

📋 Next steps:
1. Your contract is deployed to ${network}
2. The frontend is configured to use ${network} by default
3. Deploy your frontend with: pnpm next:build
4. Optional: Verify your contract on BaseScan with: pnpm verify

Your deployed contracts will be automatically available in the frontend.
`);

process.exit(0);
