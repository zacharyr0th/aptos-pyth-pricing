# Commission Contract Implementation

> Purpose: This guide explains how to implement a commission contract that uses the oracle module to convert between USD and APT for payments.

## Overview

The commission contract is a practical application of the oracle module we implemented earlier. It allows:

1. Setting a yearly commission amount in USD
2. Converting this amount to APT using the oracle's price data
3. Distributing the commission to an operator
4. Tracking commission debt if there are insufficient funds

## Implementation Steps

Let's create the `commission.move` file in the `staking/sources` directory. We'll implement it step by step:

### 1. Module Structure and Imports

```move
/// This contract is used to manage the commission rate for the node operator. There are two entities involved:
/// 1. Manager: The account that can set the commission rate and change the operator account.
/// 2. Operator: The account that receives the commission in dollars in exchange for running the node.
///
/// The commission rate is set in dollars and will be used to determine how much APT the operator receives.
/// The commission is distributed to the operator and remaining amount to the manager. If there's not enough balance
/// to pay the commission, either commission rate is set too high or APT price is low. In this case, the commission
/// debt will be updated and the operator will receive the remaining balance in the next distribution.
module staking::commission {
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::resource_account;
    use aptos_framework::timestamp;
    use aptos_std::math128;
    use aptos_std::math64;
    use staking::oracle;
    use std::signer;
    use aptos_framework::event;

    const INITIAL_COMMISSION_AMOUNT: u64 = 100000;
    const ONE_YEAR_IN_SECONDS: u64 = 31536000;
    const OCTAS_IN_ONE_APT: u128 = 100000000; // 1e8

    /// Account is not authorized to call this function.
    const EUNAUTHORIZED: u64 = 1;
```

### 2. Resource Structures

```move
    struct CommissionConfig has key {
        /// The manager of the contract who can set the commission rate.
        manager: address,
        /// The operator who receives the specified commission in dollars in exchange for running the node.
        operator: address,
        /// The yearly commission rate in dollars. Will be used to determine how much APT the operator receives.
        yearly_commission_amount: u64,
        /// Used to withdraw commission.
        signer_cap: SignerCapability,
        /// Timestamp for tracking yearly commission.
        last_update_secs: u64,
        /// Commission debt in dollars. This is used to track how much commission is owed to the operator.
        commission_debt_dollars: u64,
    }

    struct CommissionEvents has key {
        /// Event emitted when commission is distributed.
        distribute_events: event::EventHandle<DistributeEvent>,
    }

    struct DistributeEvent has drop, store {
        /// The amount of commission distributed in APT.
        commission_apt: u64,
        /// The amount of commission distributed in dollars.
        commission_dollars: u64,
        /// The price of APT in dollars.
        apt_price: u128,
        /// The timestamp when the commission was distributed.
        timestamp: u64,
    }
```

### 3. Initialization

```move
    fun init_module(staking_signer: &signer) {
        let staking_addr = signer::address_of(staking_signer);
        let (resource_signer, signer_cap) = account::create_resource_account(staking_signer, PYTH);
        move_to(staking_signer, CommissionConfig {
            manager: staking_addr,
            operator: staking_addr,
            yearly_commission_amount: INITIAL_COMMISSION_AMOUNT,
            signer_cap,
            last_update_secs: timestamp::now_seconds(),
            commission_debt_dollars: 0,
        });
        move_to(staking_signer, CommissionEvents {
            distribute_events: account::new_event_handle<DistributeEvent>(staking_signer),
        });
    }
```

### 4. Commission Calculation

```move
    /// Calculate the commission owed in dollars since the last update.
    fun commission_owed(): u64 acquires CommissionConfig {
        let config = borrow_global<CommissionConfig>(@staking);
        let now = timestamp::now_seconds();
        let time_elapsed = now - config.last_update_secs;
        
        // Calculate commission based on time elapsed
        let commission_dollars = math64::mul_div(
            config.yearly_commission_amount,
            time_elapsed,
            ONE_YEAR_IN_SECONDS
        );
        
        // Add any existing debt
        commission_dollars + config.commission_debt_dollars
    }

    /// Convert dollars to APT using the oracle price.
    fun dollars_to_apt(dollars: u64): u64 {
        let apt_price = oracle::get_apt_price();
        
        // dollars * OCTAS_IN_ONE_APT / apt_price
        // This gives us the amount of APT (in octas) for the given dollar amount
        let apt_octas = math128::mul_div(
            (dollars as u128),
            OCTAS_IN_ONE_APT,
            apt_price
        );
        
        (apt_octas as u64)
    }
```

### 5. Commission Distribution

```move
    /// Distribute commission to the operator.
    public entry fun distribute_commission() acquires CommissionConfig, CommissionEvents {
        let config = borrow_global_mut<CommissionConfig>(@staking);
        let resource_signer = account::create_signer_with_capability(&config.signer_cap);
        let resource_addr = signer::address_of(&resource_signer);
        
        // Calculate commission owed
        let commission_dollars = commission_owed();
        let commission_apt = dollars_to_apt(commission_dollars);
        
        // Check available balance
        let balance = coin::balance<AptosCoin>(resource_addr);
        
        // If not enough balance, update debt and distribute what we have
        if (balance < commission_apt) {
            // Calculate how many dollars we can pay with the available balance
            let apt_price = oracle::get_apt_price();
            let dollars_paid = math128::mul_div(
                (balance as u128),
                apt_price,
                OCTAS_IN_ONE_APT
            );
            
            // Update debt
            config.commission_debt_dollars = commission_dollars - (dollars_paid as u64);
            
            // Distribute available balance
            if (balance > 0) {
                aptos_account::transfer(&resource_signer, config.operator, balance);
            }
        } else {
            // Enough balance to pay full commission
            aptos_account::transfer(&resource_signer, config.operator, commission_apt);
            config.commission_debt_dollars = 0;
        }
        
        // Update last update timestamp
        config.last_update_secs = timestamp::now_seconds();
        
        // Emit event
        let events = borrow_global_mut<CommissionEvents>(@staking);
        event::emit_event(&mut events.distribute_events, DistributeEvent {
            commission_apt: if (balance < commission_apt) { balance } else { commission_apt },
            commission_dollars,
            apt_price: oracle::get_apt_price(),
            timestamp: timestamp::now_seconds(),
        });
    }
```

### 6. Administrative Functions

```move
    /// Set the yearly commission amount in dollars.
    public entry fun set_yearly_commission_amount(
        manager: &signer,
        yearly_commission_amount: u64
    ) acquires CommissionConfig {
        let manager_addr = signer::address_of(manager);
        let config = borrow_global_mut<CommissionConfig>(@staking);
        
        assert!(manager_addr == config.manager, EUNAUTHORIZED);
        
        // Distribute any pending commission before changing the rate
        distribute_commission();
        
        // Update commission amount
        config.yearly_commission_amount = yearly_commission_amount;
    }

    /// Change the operator address.
    public entry fun set_operator(
        manager: &signer,
        new_operator: address
    ) acquires CommissionConfig {
        let manager_addr = signer::address_of(manager);
        let config = borrow_global_mut<CommissionConfig>(@staking);
        
        assert!(manager_addr == config.manager, EUNAUTHORIZED);
        
        // Distribute any pending commission to the current operator
        distribute_commission();
        
        // Update operator
        config.operator = new_operator;
    }

    /// Change the manager address.
    public entry fun set_manager(
        manager: &signer,
        new_manager: address
    ) acquires CommissionConfig {
        let manager_addr = signer::address_of(manager);
        let config = borrow_global_mut<CommissionConfig>(@staking);
        
        assert!(manager_addr == config.manager, EUNAUTHORIZED);
        config.manager = new_manager;
    }
}
```

## Code Explanation

Let's break down the key components of this module:

### Resource Structures

- `CommissionConfig`: Stores the configuration for the commission contract, including manager and operator addresses, commission rate, and debt tracking.
- `CommissionEvents`: Handles events emitted when commission is distributed.
- `DistributeEvent`: The event structure for commission distribution.

### Commission Calculation

The contract calculates commission based on:
1. The yearly commission amount in USD
2. The time elapsed since the last distribution
3. The current APT price from the oracle

```move
fun commission_owed(): u64 acquires CommissionConfig {
    let config = borrow_global<CommissionConfig>(@staking);
    let now = timestamp::now_seconds();
    let time_elapsed = now - config.last_update_secs;
    
    // Calculate commission based on time elapsed
    let commission_dollars = math64::mul_div(
        config.yearly_commission_amount,
        time_elapsed,
        ONE_YEAR_IN_SECONDS
    );
    
    // Add any existing debt
    commission_dollars + config.commission_debt_dollars
}
```

### USD to APT Conversion

The contract uses the oracle to convert USD amounts to APT:

```move
fun dollars_to_apt(dollars: u64): u64 {
    let apt_price = oracle::get_apt_price();
    
    // dollars * OCTAS_IN_ONE_APT / apt_price
    // This gives us the amount of APT (in octas) for the given dollar amount
    let apt_octas = math128::mul_div(
        (dollars as u128),
        OCTAS_IN_ONE_APT,
        apt_price
    );
    
    (apt_octas as u64)
}
```

### Commission Distribution

The `distribute_commission` function:
1. Calculates the commission owed in USD
2. Converts it to APT using the current price
3. Checks if there's enough balance to pay the full commission
4. If not, updates the debt and pays what's available
5. Updates the last distribution timestamp
6. Emits an event with the distribution details

### Administrative Functions

The contract includes functions to:
- Set the yearly commission amount
- Change the operator address
- Change the manager address

Each of these functions checks that the caller is the current manager.

## Security Considerations

When implementing a commission contract that relies on oracle data, consider these security aspects:

1. **Price Manipulation**: Ensure the oracle has sufficient safeguards against price manipulation.
2. **Debt Accumulation**: Monitor commission debt to prevent it from growing too large.
3. **Rate Limiting**: Consider adding rate limiting to prevent too frequent distributions.
4. **Circuit Breakers**: Add circuit breakers to pause distributions during extreme market conditions.

## Next Steps

Now that you have implemented the commission contract, proceed to [Security Best Practices](./05-security-best-practices.md) to learn how to enhance the security of your oracle integration. 