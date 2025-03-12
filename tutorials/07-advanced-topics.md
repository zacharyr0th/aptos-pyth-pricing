# Advanced Topics in Oracle Integration

> Purpose: This guide explores advanced concepts and optimizations for Aptos-Pyth oracle integrations.

## Multi-Oracle Consensus

For critical applications, relying on a single oracle can be risky. Implementing a multi-oracle consensus system can enhance reliability:

```move
module staking::multi_oracle {
    use staking::oracle;
    use staking::fallback_price;
    // Hypothetical additional oracle modules
    use staking::secondary_oracle;
    use staking::tertiary_oracle;
    
    const PRICE_DEVIATION_THRESHOLD_PCT: u64 = 5; // 5% maximum deviation between oracles
    
    public fun get_consensus_price(): u128 {
        // Try to get prices from all oracles
        let primary_price_opt = get_price_safe(1);
        let secondary_price_opt = get_price_safe(2);
        let tertiary_price_opt = get_price_safe(3);
        
        // Count valid prices
        let valid_count = 0;
        if (primary_price_opt.is_some) valid_count = valid_count + 1;
        if (secondary_price_opt.is_some) valid_count = valid_count + 1;
        if (tertiary_price_opt.is_some) valid_count = valid_count + 1;
        
        // If no valid prices, abort
        assert!(valid_count > 0, 1);
        
        // If only one valid price, return it
        if (valid_count == 1) {
            if (primary_price_opt.is_some) return primary_price_opt.value;
            if (secondary_price_opt.is_some) return secondary_price_opt.value;
            return tertiary_price_opt.value;
        };
        
        // If multiple valid prices, check consensus
        if (primary_price_opt.is_some && secondary_price_opt.is_some) {
            let deviation = calculate_deviation(primary_price_opt.value, secondary_price_opt.value);
            if (deviation <= PRICE_DEVIATION_THRESHOLD_PCT) {
                // Prices are close enough, return average
                return (primary_price_opt.value + secondary_price_opt.value) / 2;
            };
        };
        
        // If no consensus, use fallback strategy (e.g., use primary if available)
        if (primary_price_opt.is_some) return primary_price_opt.value;
        if (secondary_price_opt.is_some) return secondary_price_opt.value;
        return tertiary_price_opt.value;
    }
    
    fun get_price_safe(oracle_id: u8): Option<u128> {
        // Try to get price from specified oracle
        if (oracle_id == 1) {
            // Primary oracle (Pyth)
            Option<u128> { is_some: true, value: oracle::get_apt_price() }
        } else if (oracle_id == 2) {
            // Secondary oracle
            Option<u128> { is_some: true, value: secondary_oracle::get_apt_price() }
        } else {
            // Tertiary oracle
            Option<u128> { is_some: true, value: tertiary_oracle::get_apt_price() }
        }
    }
    
    fun calculate_deviation(price1: u128, price2: u128): u64 {
        let deviation = if (price1 > price2) {
            ((price1 - price2) * 100) / price2
        } else {
            ((price2 - price1) * 100) / price1
        };
        (deviation as u64)
    }
    
    struct Option<T> has copy, drop, store {
        is_some: bool,
        value: T,
    }
}
```

## Gas Optimization Strategies

Oracle queries can be gas-intensive. Here are some strategies to optimize gas usage:

### 1. Batched Price Updates

Instead of updating prices on every transaction, batch updates at regular intervals:

```move
module staking::batched_updates {
    use aptos_framework::timestamp;
    use staking::oracle;
    
    const UPDATE_INTERVAL_SECS: u64 = 3600; // 1 hour
    
    struct BatchedPriceCache has key {
        price: u128,
        last_update_time: u64,
    }
    
    fun init_module(staking_signer: &signer) {
        move_to(staking_signer, BatchedPriceCache {
            price: 0,
            last_update_time: 0,
        });
    }
    
    public fun get_price(): u128 acquires BatchedPriceCache {
        let cache = borrow_global_mut<BatchedPriceCache>(@staking);
        let current_time = timestamp::now_seconds();
        
        // Update price if interval has passed
        if (current_time - cache.last_update_time >= UPDATE_INTERVAL_SECS || cache.price == 0) {
            cache.price = oracle::get_apt_price();
            cache.last_update_time = current_time;
        };
        
        cache.price
    }
}
```

### 2. Lazy Initialization

Initialize components only when needed:

```move
module staking::lazy_init {
    use aptos_framework::timestamp;
    use staking::oracle;
    use std::signer;
    
    struct TWAPConfig has key {
        is_initialized: bool,
        price_history: vector<PricePoint>,
    }
    
    struct PricePoint has store {
        price: u128,
        timestamp: u64,
    }
    
    public fun ensure_initialized(account: &signer) {
        let account_addr = signer::address_of(account);
        
        if (!exists<TWAPConfig>(account_addr)) {
            move_to(account, TWAPConfig {
                is_initialized: true,
                price_history: vector::empty<PricePoint>(),
            });
        };
    }
    
    public fun update_price_history(account: &signer) acquires TWAPConfig {
        ensure_initialized(account);
        
        let config = borrow_global_mut<TWAPConfig>(signer::address_of(account));
        
        // Add new price point
        vector::push_back(&mut config.price_history, PricePoint {
            price: oracle::get_apt_price(),
            timestamp: timestamp::now_seconds(),
        });
    }
}
```

## Advanced Security Features

### 1. Governance-Controlled Parameters

Allow governance to update critical parameters:

```move
module staking::governance {
    use std::signer;
    
    const EUNAUTHORIZED: u64 = 1;
    
    struct GovernanceConfig has key {
        admin: address,
        max_price_change_pct: u64,
        max_confidence_pct: u64,
        max_staleness_secs: u64,
    }
    
    fun init_module(staking_signer: &signer) {
        move_to(staking_signer, GovernanceConfig {
            admin: signer::address_of(staking_signer),
            max_price_change_pct: 20,
            max_confidence_pct: 5,
            max_staleness_secs: 120,
        });
    }
    
    public entry fun update_max_price_change_pct(
        admin: &signer,
        new_value: u64
    ) acquires GovernanceConfig {
        let admin_addr = signer::address_of(admin);
        let config = borrow_global<GovernanceConfig>(@staking);
        
        assert!(admin_addr == config.admin, EUNAUTHORIZED);
        
        let config_mut = borrow_global_mut<GovernanceConfig>(@staking);
        config_mut.max_price_change_pct = new_value;
    }
    
    // Similar functions for other parameters
}
```

### 2. Timelocked Operations

Implement timelock for sensitive operations:

```move
module staking::timelock {
    use aptos_framework::timestamp;
    use std::signer;
    
    const EUNAUTHORIZED: u64 = 1;
    const ETIMELOCK_NOT_EXPIRED: u64 = 2;
    
    struct TimelockOperation has key, store {
        operation_type: u8,
        params: vector<u8>,
        execution_time: u64,
        proposer: address,
    }
    
    struct TimelockConfig has key {
        admin: address,
        delay_secs: u64,
        pending_operations: vector<TimelockOperation>,
    }
    
    fun init_module(staking_signer: &signer) {
        move_to(staking_signer, TimelockConfig {
            admin: signer::address_of(staking_signer),
            delay_secs: 86400, // 24 hours
            pending_operations: vector::empty<TimelockOperation>(),
        });
    }
    
    public entry fun propose_operation(
        admin: &signer,
        operation_type: u8,
        params: vector<u8>
    ) acquires TimelockConfig {
        let admin_addr = signer::address_of(admin);
        let config = borrow_global<TimelockConfig>(@staking);
        
        assert!(admin_addr == config.admin, EUNAUTHORIZED);
        
        let config_mut = borrow_global_mut<TimelockConfig>(@staking);
        vector::push_back(&mut config_mut.pending_operations, TimelockOperation {
            operation_type,
            params,
            execution_time: timestamp::now_seconds() + config.delay_secs,
            proposer: admin_addr,
        });
    }
    
    public entry fun execute_operation(
        admin: &signer,
        operation_index: u64
    ) acquires TimelockConfig {
        let admin_addr = signer::address_of(admin);
        let config = borrow_global<TimelockConfig>(@staking);
        
        assert!(admin_addr == config.admin, EUNAUTHORIZED);
        assert!(operation_index < vector::length(&config.pending_operations), 3);
        
        let operation = vector::borrow(&config.pending_operations, operation_index);
        assert!(timestamp::now_seconds() >= operation.execution_time, ETIMELOCK_NOT_EXPIRED);
        
        // Execute operation based on type
        if (operation.operation_type == 1) {
            // Update max price change percentage
            // Parse params and execute
        } else if (operation.operation_type == 2) {
            // Update max confidence percentage
            // Parse params and execute
        };
        
        // Remove operation from pending list
        let config_mut = borrow_global_mut<TimelockConfig>(@staking);
        vector::remove(&mut config_mut.pending_operations, operation_index);
    }
}
```

## Performance Monitoring

Implement monitoring to track oracle performance:

```move
module staking::monitoring {
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use staking::oracle;
    
    struct PriceAnomaly has drop, store {
        price: u128,
        previous_price: u128,
        change_pct: u64,
        timestamp: u64,
    }
    
    struct OracleMetrics has key {
        last_price: u128,
        last_update_time: u64,
        price_anomaly_events: event::EventHandle<PriceAnomaly>,
        total_queries: u64,
        failed_queries: u64,
    }
    
    fun init_module(staking_signer: &signer) {
        move_to(staking_signer, OracleMetrics {
            last_price: 0,
            last_update_time: 0,
            price_anomaly_events: account::new_event_handle<PriceAnomaly>(staking_signer),
            total_queries: 0,
            failed_queries: 0,
        });
    }
    
    public fun record_price_query(success: bool) acquires OracleMetrics {
        let metrics = borrow_global_mut<OracleMetrics>(@staking);
        
        metrics.total_queries = metrics.total_queries + 1;
        if (!success) {
            metrics.failed_queries = metrics.failed_queries + 1;
        };
    }
    
    public fun check_price_anomaly(anomaly_threshold_pct: u64) acquires OracleMetrics {
        let metrics = borrow_global_mut<OracleMetrics>(@staking);
        let current_price = oracle::get_apt_price();
        let current_time = timestamp::now_seconds();
        
        if (metrics.last_price > 0) {
            let change_pct = if (current_price > metrics.last_price) {
                ((current_price - metrics.last_price) * 100) / metrics.last_price
            } else {
                ((metrics.last_price - current_price) * 100) / current_price
            };
            
            if ((change_pct as u64) > anomaly_threshold_pct) {
                // Emit anomaly event
                event::emit_event(&mut metrics.price_anomaly_events, PriceAnomaly {
                    price: current_price,
                    previous_price: metrics.last_price,
                    change_pct: (change_pct as u64),
                    timestamp: current_time,
                });
            };
        };
        
        // Update metrics
        metrics.last_price = current_price;
        metrics.last_update_time = current_time;
    }
}
```

## Conclusion

In this tutorial series, you've learned how to:

1. Set up an Aptos-Pyth oracle integration
2. Implement a price oracle module
3. Create a commission contract that uses price data
4. Add security features like circuit breakers and fallback mechanisms
5. Test and deploy your integration
6. Implement advanced features for better security and performance

By following these best practices, you can build reliable and secure oracle integrations for your Aptos smart contracts. Remember that oracles are critical infrastructure for DeFi applications, and their security and reliability directly impact the security of your entire protocol. Always prioritize thorough testing, monitoring, and security measures when working with oracle integrations. 