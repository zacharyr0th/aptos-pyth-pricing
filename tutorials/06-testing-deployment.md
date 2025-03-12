# Testing and Deployment

> Purpose: This guide explains how to test and deploy your Aptos-Pyth oracle integration to testnet and mainnet.

## Testing Your Oracle Integration

Thorough testing is crucial for oracle integrations, as they handle financial data and can impact user funds. Let's implement a comprehensive testing strategy:

### 1. Unit Testing

Create a test file in the `staking/tests` directory:

```move
#[test_only]
module staking::oracle_tests {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use staking::oracle;

    const STAKING: address = @staking;

    #[test]
    fun test_get_apt_price() {
        // Set up test environment
        let staking = account::create_account_for_test(STAKING);
        timestamp::set_time_has_started_for_testing(&staking);
        
        // Initialize oracle module
        oracle::init_module_for_test(&staking);
        
        // Set test price
        oracle::set_test_price(5000000000); // $50 with 8 decimals
        
        // Verify price
        let price = oracle::get_apt_price();
        assert!(price == 5000000000, 0);
    }

    #[test]
    #[expected_failure(abort_code = staking::oracle::ESTALE_PRICE)]
    fun test_stale_price() {
        // Set up test environment
        let staking = account::create_account_for_test(STAKING);
        timestamp::set_time_has_started_for_testing(&staking);
        
        // Initialize oracle module with very short max age
        oracle::init_module_for_test(&staking);
        oracle::set_max_age_secs_for_test(&staking, 1);
        
        // Set test price
        oracle::set_test_price(5000000000);
        
        // Advance time beyond max age
        timestamp::fast_forward_seconds(2);
        
        // This should fail with ESTALE_PRICE
        oracle::get_apt_price();
    }
}
```

### 2. Commission Contract Tests

```move
#[test_only]
module staking::commission_tests {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use staking::commission;
    use staking::oracle;

    const STAKING: address = @staking;
    const MANAGER: address = @manager;
    const OPERATOR: address = @operator;

    #[test]
    fun test_distribute_commission() {
        // Set up test environment
        let staking = account::create_account_for_test(STAKING);
        let manager = account::create_account_for_test(MANAGER);
        let operator = account::create_account_for_test(OPERATOR);
        
        timestamp::set_time_has_started_for_testing(&staking);
        
        // Initialize modules
        oracle::init_module_for_test(&staking);
        commission::init_module_for_test(&staking);
        
        // Set test price: $50 per APT
        oracle::set_test_price(5000000000);
        
        // Set commission amount: $100,000 per year
        commission::set_yearly_commission_amount_for_test(&staking, 100000);
        
        // Set operator
        commission::set_operator_for_test(&staking, OPERATOR);
        
        // Create and fund resource account
        let resource_addr = commission::get_resource_account_address();
        aptos_coin::mint_for_test(resource_addr, 10 * 100000000); // 10 APT
        
        // Fast forward 1/4 of a year
        timestamp::fast_forward_seconds(31536000 / 4);
        
        // Distribute commission
        commission::distribute_commission();
        
        // Verify operator received ~$25,000 worth of APT (0.5 APT at $50/APT)
        let operator_balance = coin::balance<AptosCoin>(OPERATOR);
        assert!(operator_balance == 5 * 10000000, 0); // 0.5 APT
    }
}
```

### 3. Integration Tests with Circuit Breakers

```move
#[test_only]
module staking::integration_tests {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use staking::oracle;
    use staking::commission;
    use staking::circuit_breaker;

    const STAKING: address = @staking;
    const ADMIN: address = @staking;

    #[test]
    #[expected_failure(abort_code = staking::circuit_breaker::EPAUSED)]
    fun test_circuit_breaker() {
        // Set up test environment
        let staking = account::create_account_for_test(STAKING);
        timestamp::set_time_has_started_for_testing(&staking);
        
        // Initialize modules
        oracle::init_module_for_test(&staking);
        commission::init_module_for_test(&staking);
        circuit_breaker::init_module_for_test(&staking);
        
        // Set test price
        oracle::set_test_price(5000000000);
        
        // Pause circuit breaker
        circuit_breaker::emergency_pause(&staking, 3600); // 1 hour
        
        // This should fail because circuit breaker is paused
        commission::distribute_commission();
    }

    #[test]
    #[expected_failure(abort_code = staking::circuit_breaker::EPRICE_CHANGE_EXCEEDS_THRESHOLD)]
    fun test_price_change_threshold() {
        // Set up test environment
        let staking = account::create_account_for_test(STAKING);
        timestamp::set_time_has_started_for_testing(&staking);
        
        // Initialize modules
        oracle::init_module_for_test(&staking);
        commission::init_module_for_test(&staking);
        circuit_breaker::init_module_for_test(&staking);
        
        // Set initial price and update circuit breaker
        oracle::set_test_price(5000000000);
        circuit_breaker::check_circuit_breaker();
        
        // Change price dramatically (50% increase)
        oracle::set_test_price(7500000000);
        
        // This should fail because price change exceeds threshold
        circuit_breaker::check_circuit_breaker();
    }
}
```

### 4. Running Tests

Run your tests using the Aptos CLI:

```bash
aptos move test --package-dir aptos-pyth-pricing/staking/ --named-addresses staking=0xcafe,manager=0x123,operator=0x124,pyth=0x182
```

## Deployment Process

### 1. Testnet Deployment

Before deploying to mainnet, always test your contract on testnet:

```bash
# Create a profile for testnet if you haven't already
aptos init --profile testnet --network testnet

# Publish to testnet
aptos move publish \
  --package-dir aptos-pyth-pricing/staking/ \
  --named-addresses staking=<YOUR_TESTNET_ADDRESS>,manager=<MANAGER_ADDRESS>,operator=<OPERATOR_ADDRESS>,pyth=0x7e783b5b9ae3d8ee476c9b5853dddca67601c8d84ffd5f6d5d5b4f1bf3e9e56
```

### 2. Initialize the Contract

After deployment, initialize the contract:

```bash
# Initialize commission contract
aptos move run \
  --function-id <YOUR_TESTNET_ADDRESS>::commission::initialize \
  --profile testnet
```

### 3. Set Commission Amount

```bash
# Set yearly commission amount (in dollars)
aptos move run \
  --function-id <YOUR_TESTNET_ADDRESS>::commission::set_yearly_commission_amount \
  --args u64:100000 \
  --profile testnet
```

### 4. Set Operator

```bash
# Set operator address
aptos move run \
  --function-id <YOUR_TESTNET_ADDRESS>::commission::set_operator \
  --args address:<OPERATOR_ADDRESS> \
  --profile testnet
```

### 5. Fund the Resource Account

The resource account needs APT to distribute as commission:

```bash
# Get resource account address
aptos move run \
  --function-id <YOUR_TESTNET_ADDRESS>::commission::get_resource_account_address \
  --profile testnet

# Transfer APT to resource account
aptos move run \
  --function-id 0x1::aptos_account::transfer \
  --args address:<RESOURCE_ACCOUNT_ADDRESS> u64:<AMOUNT_IN_OCTAS> \
  --profile testnet
```

### 6. Distribute Commission

```bash
# Distribute commission
aptos move run \
  --function-id <YOUR_TESTNET_ADDRESS>::commission::distribute_commission \
  --profile testnet
```

## Mainnet Deployment

When you're ready to deploy to mainnet, follow these steps:

### 1. Security Audit

Before deploying to mainnet:
- Conduct a thorough security audit of your code
- Consider hiring a professional auditor for critical contracts
- Run extensive tests with various price scenarios

### 2. Deployment

```bash
# Create a profile for mainnet
aptos init --profile mainnet --network mainnet

# Publish to mainnet
aptos move publish \
  --package-dir aptos-pyth-pricing/staking/ \
  --named-addresses staking=<YOUR_MAINNET_ADDRESS>,manager=<MANAGER_ADDRESS>,operator=<OPERATOR_ADDRESS>,pyth=<PYTH_MAINNET_ADDRESS> \
  --profile mainnet
```

### 3. Monitoring

After deployment, set up monitoring:

- Monitor price feeds for anomalies
- Track commission distributions
- Set up alerts for circuit breaker activations
- Monitor commission debt

## Troubleshooting Common Issues

### 1. Stale Price Errors

If you encounter stale price errors:
- Check that Pyth Network is operational
- Verify your max age setting is appropriate
- Implement fallback mechanisms

### 2. Insufficient Balance

If the resource account has insufficient balance:
- Verify the commission amount is reasonable
- Check APT price movements
- Monitor and fund the resource account regularly

### 3. Circuit Breaker Activations

If circuit breakers activate frequently:
- Adjust the price change threshold
- Investigate price volatility
- Consider using TWAP for more stability

## Next Steps

Now that you've learned how to test and deploy your oracle integration, proceed to [Advanced Topics](./07-advanced-topics.md) to explore advanced concepts and optimizations. 