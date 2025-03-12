# Getting Started with Aptos-Pyth Integration

> Purpose: This guide helps you set up your development environment and project structure for integrating Pyth Network price feeds with Aptos smart contracts.

## Development Environment Setup

Before diving into the implementation, let's set up our development environment:

### Prerequisites

1. **Install Aptos CLI**

   The Aptos CLI is essential for compiling, testing, and deploying Move modules:

   ```bash
   # For macOS
   brew install aptos
   
   # For other platforms, see: https://aptos.dev/tools/aptos-cli/install-cli/
   ```

   Verify installation:
   ```bash
   aptos --version
   ```

2. **Set Up Aptos Account**

   ```bash
   # Generate a new key
   aptos key generate --output-file ~/.aptos/key.json
   
   # Create a profile for testnet
   aptos init --profile testnet --network testnet
   ```

## Project Structure

Let's create our project structure:

```bash
mkdir -p aptos-pyth-pricing/staking/sources
mkdir -p aptos-pyth-pricing/staking/tests
cd aptos-pyth-pricing
```

### Create Move.toml

Create a `Move.toml` file in the `staking` directory:

```toml
[package]
name = "Staking"
version = "1.0.0"

[addresses]
staking = "_"
manager = "_"
operator = "_"
pyth = "0x7e783b5b9ae3d8ee476c9b5853dddca67601c8d84ffd5f6d5d5b4f1bf3e9e56"

[dependencies]
AptosFramework = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-framework", rev = "mainnet" }
Pyth = { git = "https://github.com/pyth-network/pyth-crosschain.git", subdir = "target_chains/aptos/contracts", rev = "main" }
```

The `pyth` address is the deployed Pyth contract on Aptos testnet. For mainnet, you would use the appropriate mainnet address.

## Understanding the Project Components

Our integration consists of two main modules:

1. **Oracle Module (`oracle.move`)**
   - Interfaces with Pyth Network to fetch price data
   - Normalizes price data to a standard format
   - Provides price staleness checks

2. **Commission Contract (`commission.move`)**
   - Uses price data from the oracle module
   - Calculates commission in USD and converts to APT
   - Distributes commission to operators

In the following tutorials, we'll implement these modules step by step, starting with the oracle module.

## Next Steps

Now that you have your environment set up, proceed to [Understanding Pyth Network](./02-understanding-pyth.md) to learn how Pyth price feeds work and how to integrate them with Aptos. 