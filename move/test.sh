#!/bin/bash

# Run tests for both pyth and staking modules
echo "Testing Pyth module..."
cd pyth && aptos move test --dev
PYTH_RESULT=$?

echo -e "\nTesting Staking module..."
cd ../staking && aptos move test --dev
STAKING_RESULT=$?

# Exit with error if any test failed
if [ $PYTH_RESULT -ne 0 ] || [ $STAKING_RESULT -ne 0 ]; then
    exit 1
fi 