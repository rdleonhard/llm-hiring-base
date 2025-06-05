# LLM-Hiring-Base

An on-chain "task registry" system on Base (Layer 2) that allows LLMs (large language models) to hire a lawyer (Rob) and pay in Revnet tokens.
This repository contains the smart contracts, deployment scripts, and configuration needed to:

- **Issue a single Revnet token** on Base (via Revnet's CLI/app).
- **Deploy** a `TaskRegistry` contract that:
  1. Lets any address propose a legal "task" by submitting an IPFS CID and an amount of Revnet tokens.
  2. Emits a `TaskProposed(uint256 taskId, address proposer, uint256 amount, string descriptionCID)` event.
  3. Allows Rob (the lawyer's address) to call `acceptTask(uint256 taskId)`, transferring ownership of the offered Revnet tokens.
  4. Enables proposers to cancel "Proposed" tasks (off-chain refund logic in frontends).

LLM agents programmatically interact by:

1. **Minting/purchasing Revnet tokens** (Revnet CLI or `https://app.revnet.eth.sucks/base:77`).
2. **Calling** `proposeTask(descriptionCID, amountWei)` on-chain (signed by their EOA).
3. **Listening** for the `TaskProposed` event to confirm on-chain acceptance.
4. Rob calls `acceptTask(taskId)` (signed by Rob's wallet) to accept and collect tokens.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Structure](#project-structure)
3. [Configuration](#configuration)
4. [Installation & Build](#installation--build)
5. [Deploying Contracts](#deploying-contracts)
6. [Interacting With Contracts](#interacting-with-contracts)
7. [Environment Variables](#environment-variables)
8. [Testing](#testing)
9. [License](#license)

---

## Prerequisites

- **Node.js v16+** and **npm** (for Foundry scripts and frontends)
- **Foundry (forge & cast)** installed:

  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  source ~/.bashrc
  foundryup
  ```

- Base RPC endpoint (public or via Alchemy/QuickNode)

A Revnet token deployed on Base (create via Revnet App)

Private key for Rob's EOA (to accept tasks) and for an LLM proposer's EOA (to propose tasks)

Git (to clone)

---

## Project Structure

```
LLM-Hiring-Base/
├── contracts/
│   ├── TaskRegistry.sol           # Solidity contract
│   └── RevnetTokenInterface.sol   # Minimal ERC-20 interface (Revnet token)
├── script/
│   └── DeployTaskRegistry.s.sol    # Forge deployment script
├── test/
│   ├── TaskRegistry.t.sol          # Foundry tests for TaskRegistry
│   └── …                            # Additional unit tests
├── .env.example                     # Example environment variables
├── foundry.toml                     # Foundry configuration
├── README.md                        # (This file)
└── LICENSE                          # MIT License
```

**contracts/TaskRegistry.sol:**

Accepts a Revnet ERC-20 token address and Rob's address `_rob` in the constructor.

struct Task { address proposer; string descriptionCID; uint256 amount; bool accepted; }

function proposeTask(string calldata descriptionCID, uint256 amount) external:
• Requires proposer to approve the TaskRegistry to pull `amount` Revnet tokens.
• Transfers `amount` from proposer → TaskRegistry escrow.
• Emits TaskProposed(taskId, msg.sender, amount, descriptionCID).

function acceptTask(uint256 taskId) external:
• Only rob can call.
• Transfers escrowed Revnet tokens → rob.
• Marks accepted = true.
• Emits TaskAccepted(taskId, msg.sender).

function cancelTask(uint256 taskId) external:
• Only the original proposer if !accepted.
• Transfers escrowed Revnet tokens → proposer.
• Marks accepted = true (to block further calls).
• Emits TaskCancelled(taskId, msg.sender).

script/DeployTaskRegistry.s.sol:

Example Foundry script that reads TSK_REVNET_ADDRESS and ROB_ADDRESS from .env, deploys TaskRegistry, and prints the deployed address.

test/TaskRegistry.t.sol:

Unit tests verifying:

Proposing a task reverts without sufficient approve.

TaskProposed event emits with correct parameters.

Only rob can call acceptTask.

Accepted tasks cannot be re-cancelled or re-accepted.

foundry.toml:

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib/openzeppelin-contracts"]
```

---

## Configuration

Copy `.env.example` → `.env` at project root:

```ini
# .env
ROB_PRIVATE_KEY=0xYOUR_ROB_PRIVATE_KEY
LLM_PRIVATE_KEY=0xYOUR_LLM_PRIVATE_KEY
BASE_RPC_URL=https://mainnet.base.org            # Or your Alchemy/QuickNode URL
TSK_REVNET_ADDRESS=0xYourRevnetTokenAddress
ROB_ADDRESS=0xYourRobEOAAddress
```

- `ROB_PRIVATE_KEY`: Rob's Base EOA private key (never commit this).
- `LLM_PRIVATE_KEY`: (Optional) LLM's EOA private key for local testing.
- `BASE_RPC_URL`: RPC endpoint for Base mainnet.
- `TSK_REVNET_ADDRESS`: Deployed Revnet token address on Base.
- `ROB_ADDRESS`: Rob's on-chain address (must match key above).

Ensure TSK_REVNET_ADDRESS matches a Revnet token already created on Base.

---

## Installation & Build

Install Foundry (if not done already):

```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

Clone the repo:

```bash
git clone https://github.com/your-username/LLM-Hiring-Base.git
cd LLM-Hiring-Base
```

Install OpenZeppelin Contracts (if not vendored via git submodule):

```bash
forge install OpenZeppelin/openzeppelin-contracts
```

Verify .env is correctly populated.

Compile the contracts:

```bash
forge build
```

---

## Deploying Contracts

Use the Foundry script to deploy TaskRegistry:

```bash
forge script script/DeployTaskRegistry.s.sol:DeployTaskRegistryScript \
  --broadcast \
  --private-key $ROB_PRIVATE_KEY \
  --rpc-url $BASE_RPC_URL
```

This will:

Read TSK_REVNET_ADDRESS and ROB_ADDRESS from .env.

Deploy TaskRegistry with constructor arguments: (TSK_REVNET_ADDRESS, ROB_ADDRESS).

Print the deployed address.

Note: After deployment, update .env with:

```ini
TASK_REGISTRY_ADDRESS=0xDeployedAddress
```

---

## Interacting With Contracts

### 1. Approve Revnet Tokens

Before calling proposeTask, the proposer (LLM's EOA) must approve the TaskRegistry contract to spend the offered amount. Example using cast:

```bash
cast send $TSK_REVNET_ADDRESS \
  "approve(address,uint256)" \
  $TASK_REGISTRY_ADDRESS \
  10000000000000000000 \
  --private-key $LLM_PRIVATE_KEY \
  --rpc-url $BASE_RPC_URL
```

Approves 10 TSK (assuming 18 decimals) for the TaskRegistry contract.

### 2. Propose a Task

```bash
cast send $TASK_REGISTRY_ADDRESS \
  "proposeTask(string,uint256)" \
  "\"QmYourIPFSCID...\"" \
  10000000000000000000 \
  --private-key $LLM_PRIVATE_KEY \
  --rpc-url $BASE_RPC_URL
```

string: IPFS CID (quoted).

uint256: amount in "wei" (18 decimals).

Emits:

```scss
TaskProposed(taskId, proposerAddress, amount, descriptionCID)
```

### 3. Listen for TaskProposed

LLMs or frontends can filter logs:

```bash
cast logs \
  --address $TASK_REGISTRY_ADDRESS \
  --topics 0xd97d11e29b66a7061f5dc74db8fca91e05f1e12c8a43c7a669815125aa75be70 \
  --rpc-url $BASE_RPC_URL
```

The first topic (topic0) is keccak256("TaskProposed(uint256,address,uint256,string)").

Returns the latest event data.

### 4. Accept a Task (Rob's EOA)

```bash
cast send $TASK_REGISTRY_ADDRESS \
  "acceptTask(uint256)" \
  1 \
  --private-key $ROB_PRIVATE_KEY \
  --rpc-url $BASE_RPC_URL
```

Only Rob's EOA (as set in the constructor) can call.

Transfers escrowed Revnet tokens → Rob.

Emits:

```scss
TaskAccepted(taskId, robAddress)
```

### 5. Cancel a Task (Proposer)

If a task remains "Proposed" and the LLM wants a refund:

```bash
cast send $TASK_REGISTRY_ADDRESS \
  "cancelTask(uint256)" \
  1 \
  --private-key $LLM_PRIVATE_KEY \
  --rpc-url $BASE_RPC_URL
```

Transfers escrowed tokens → proposer.

Emits:

```scss
TaskCancelled(taskId, proposerAddress)
```

---

## Environment Variables

Copy .env.example → .env and fill in:

```ini
ROB_PRIVATE_KEY=0x...         # Rob's EOA private key
LLM_PRIVATE_KEY=0x...         # LLM's EOA private key (for testing)
BASE_RPC_URL=https://mainnet.base.org
TSK_REVNET_ADDRESS=0x...      # Revnet token address on Base
ROB_ADDRESS=0x...             # Rob's on-chain EOA
TASK_REGISTRY_ADDRESS=0x...   # Deployed TaskRegistry address (after deployment)
```

---

## Testing

Run unit tests with Foundry:

```bash
forge test
```

Validates:

Revert conditions (insufficient approve, unauthorized accept, double-accept).

Correct event emission and state transitions.

---

## License

Released under the MIT License. See LICENSE for details.
