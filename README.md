# Aptos-Pyth Oracle Integration

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This project demonstrates how to integrate Pyth Network price feeds with Aptos smart contracts.

## Project Structure

```
aptos-pyth-pricing/
├── docs/                  # Additional documentation
├── tutorials/            # Step-by-step tutorial series
│   ├── 00-overview.md
│   ├── 01-getting-started.md
│   ├── 02-understanding-pyth.md
│   ├── 03-oracle-implementation.md
│   ├── 04-security-monitoring.md
│   ├── 05-testing.md
│   ├── 06-deployment.md
│   └── 07-advanced-features.md
├── aptos-pyth-pricing/   # Core implementation
│   ├── staking/         # Oracle and commission contracts
│   │   ├── Move.toml
│   │   ├── sources/
│   │   │   ├── oracle.move
│   │   │   └── commission.move
│   │   └── tests/
│   └── pyth/            # Pyth Network integration
│       ├── Move.toml
│       └── sources/
│           ├── price_identifier.move
│           ├── pyth.move
│           ├── price.move
│           └── i64.move
```

## Tutorial Series

| Tutorial | Implementation Topics | Key Concepts |
|----------|---------------------|--------------|
| [1. Getting Started](./tutorials/01-getting-started.md) | • Development environment setup<br>• Project structure creation<br>• Dependencies configuration | • Move programming<br>• Project organization |
| [2. Understanding Pyth Network](./tutorials/02-understanding-pyth.md) | • Pyth Network architecture<br>• Price feed structure | • Price feed integration<br>• Data normalization |
| [3. Oracle Implementation](./tutorials/03-oracle-implementation.md) | • Oracle module implementation<br>• Commission contract implementation | • Price normalization<br>• Commission calculation |
| [4. Commission Contract](./tutorials/04-commission-contract.md) | • Contract implementation<br>• Fee calculation<br>• State management | • Contract design<br>• Fee structures |
| [5. Security Best Practices](./tutorials/05-security-best-practices.md) | • Circuit breakers<br>• Price validation<br>• Monitoring systems | • Security patterns<br>• Monitoring patterns |
| [6. Testing & Deployment](./tutorials/06-testing-deployment.md) | • Unit testing<br>• Integration testing<br>• Deployment process | • Test organization<br>• Deployment steps |
| [7. Advanced Topics](./tutorials/07-advanced-topics.md) | • Multi-oracle consensus<br>• Gas optimization | • Advanced patterns<br>• Optimization |

## Core Components

1. **Pyth Integration (`pyth/`)**
   - `i64.move`: Signed integer implementation
   - `price.move`: Price feed data structures
   - `price_identifier.move`: Price feed ID handling
   - `pyth.move`: Core Pyth Network interface

2. **Staking Module (`staking/`)**
   - `oracle.move`: Price oracle implementation
   - `commission.move`: Commission contract logic
   - Unit and integration tests

## Prerequisites

- Basic understanding of Move programming language
- Familiarity with Aptos blockchain concepts
- Aptos CLI installed (see [installation guide](https://aptos.dev/tools/aptos-cli/install-cli/))
- Understanding of oracle concepts

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
   aptos move compile --package-dir aptos-pyth-pricing/

   # Run tests
   aptos move test --package-dir aptos-pyth-pricing/ --named-addresses staking=0xcafe,manager=0x123,operator=0x124,pyth=0x182
   ```

## Documentation

For detailed documentation, follow our tutorial series in the `tutorials/` directory, starting with [00-overview.md](tutorials/00-overview.md).

## Additional Resources

- [Aptos Documentation](https://aptos.dev)
- [Pyth Network Documentation](https://docs.pyth.network)

## License

This project is licensed under the MIT License.

```

See the [LICENSE](./LICENSE) file for the full license text.