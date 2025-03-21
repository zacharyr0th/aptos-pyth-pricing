# Aptos-Pyth Oracle Integration

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A tutorial on using Pyth oracle prices in Aptos smart contracts.

## Project Structure

```
aptos-pyth-pricing/
├── move/                 # Core implementation
│   ├── staking/         # Oracle and commission contracts
│   │   ├── Move.toml
│   │   ├── sources/     # Contract source files
│   │   └── tests/       # Contract test files
│   ├── pyth/            # Pyth Network integration
│   │   ├── Move.toml
│   │   └── sources/     # Pyth interface implementations
│   └── test.sh          # Automated test script for all modules
├── tutorials/           # Step-by-step tutorial series
│   ├── README.md        # Tutorial overview and index
│   ├── 01-understanding-pyth.md
│   ├── 02-commission-contract.md
│   ├── 03-oracle-implementation.md
│   └── 04-security-best-practices.md
├── .gitignore
├── LICENSE
└── README.md
```

## Tutorial Series

| Tutorial | Implementation Topics | Key Concepts |
|----------|---------------------|--------------|
| [1. Understanding Pyth](./tutorials/01-understanding-pyth.md) | • Pyth Network architecture<br>• Price feed structure<br>• Interface overview | • Price feed integration<br>• Data structures<br>• Core concepts |
| [2. Commission Contract](./tutorials/02-commission-contract.md) | • Contract implementation<br>• Fee calculation<br>• State management | • Contract design<br>• Fee structures<br>• Debt tracking |
| [3. Oracle Implementation](./tutorials/03-oracle-implementation.md) | • Oracle module implementation<br>• Price feed integration<br>• Configuration management | • Price normalization<br>• Oracle design<br>• Security features |
| [4. Security Best Practices](./tutorials/04-security-best-practices.md) | • Circuit breakers<br>• Price validation<br>• Access control<br>• Monitoring systems | • Security patterns<br>• Debt protection<br>• Testing requirements |

## Core Components

1. **Pyth Integration (`move/pyth/`)**
   - Price feed data structures
   - Price feed ID handling
   - Core Pyth Network interface

2. **Staking Module (`move/staking/`)**
   - Price oracle implementation
   - Commission contract logic
   - Unit and integration tests


## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/aptos-pyth-pricing.git
   cd aptos-pyth-pricing
   ```

2. Install dependencies:
   ```bash
   # Install Aptos CLI
   brew install aptos
   
   # Verify installation
   aptos --version
   ```

3. Set up your development environment:
   ```bash
   # Generate a new key
   aptos key generate --output-file ~/.aptos/key.json
   
   # Create a profile for testnet
   aptos init --profile testnet --network testnet
   ```

4. Build and test:
   ```bash
   # Compile the modules
   aptos move compile --package-dir move/staking/
   aptos move compile --package-dir move/pyth/

   # Run tests (Option 1: Individual modules)
   aptos move test --package-dir move/staking/
   aptos move test --package-dir move/pyth/

   # Run tests (Option 2: All modules using test script)
   cd move && ./test.sh
   ```

## Documentation

For detailed documentation, follow our tutorial series in the `tutorials/` directory, starting with [Understanding Pyth](tutorials/01-understanding-pyth.md).

## Additional Resources

- [Aptos Documentation](https://aptos.dev)
- [Pyth Network Documentation](https://docs.pyth.network)

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.
