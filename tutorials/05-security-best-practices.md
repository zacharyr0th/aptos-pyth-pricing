# Security Best Practices for Oracle Integrations

> Purpose: This guide outlines security best practices and risk mitigation strategies for oracle integrations in Aptos smart contracts.

## Oracle Security Risks

Oracles are critical components in DeFi applications, but they also introduce specific security risks:

### 1. Price Manipulation Attacks

Attackers may attempt to manipulate the price reported by oracles to exploit your contract:

- **Flash Loan Attacks**: Temporarily manipulating market prices to exploit oracle readings
- **Publisher Compromise**: If enough Pyth publishers are compromised, price data could be falsified
- **Network Latency Exploitation**: Taking advantage of delayed price updates during high volatility

### 2. Staleness Risk

Price data may become stale due to:
- Network congestion
- Oracle service outages
- Blockchain congestion preventing updates

### 3. Precision and Rounding Errors

Mathematical operations involving price data can lead to precision and rounding errors, especially when:
- Converting between different units (e.g., USD to APT)
- Calculating percentages or fees
- Accumulating small errors over time

## Security Enhancements

Let's implement several security enhancements to mitigate these risks:

### 1. Circuit Breaker Implementation

Circuit breakers pause contract operations during extreme market conditions or when price data appears suspicious:

```move
module staking::circuit_breaker {
    use aptos_framework::timestamp;
    use staking::oracle;
    use std::signer;

    /// Circuit breaker is paused
    const EPAUSED: u64 = 1;
    /// Not authorized to pause/unpause
    const EUNAUTHORIZED: u64 = 2;
    /// Price change exceeds threshold
    const EPRICE_CHANGE_EXCEEDS_THRESHOLD: u64 = 3;

    struct CircuitBreaker has key {
        is_paused: bool,
        last_valid_price: u128,
        pause_until_timestamp: u64,
        max_price_change_pct: u64, // Maximum allowed price change in percentage (e.g., 20 for 20%)
        admin: address,
    }

    fun init_module(staking_signer: &signer) {
        move_to(staking_signer, CircuitBreaker {
            is_paused: false,
            last_valid_price: 0,
            pause_until_timestamp: 0,
            max_price_change_pct: 20, // 20% default
            admin: signer::address_of(staking_signer),
        });
    }

    public fun check_circuit_breaker() acquires CircuitBreaker {
        let breaker = borrow_global<CircuitBreaker>(@staking);
        
        // Check if manually paused
        if (breaker.is_paused && timestamp::now_seconds() < breaker.pause_until_timestamp) {
            abort EPAUSED
        };
        
        // Auto-unpause if pause period has elapsed
        if (breaker.is_paused && timestamp::now_seconds() >= breaker.pause_until_timestamp) {
            let breaker_mut = borrow_global_mut<CircuitBreaker>(@staking);
            breaker_mut.is_paused = false;
        };
        
        // Check for suspicious price changes
        if (breaker.last_valid_price > 0) {
            let current_price = oracle::get_apt_price();
            let price_change_pct = if (current_price > breaker.last_valid_price) {
                // Price increased
                ((current_price - breaker.last_valid_price) * 100) / breaker.last_valid_price
            } else {
                // Price decreased
                ((breaker.last_valid_price - current_price) * 100) / breaker.last_valid_price
            };
            
            if ((price_change_pct as u64) > breaker.max_price_change_pct) {
                abort EPRICE_CHANGE_EXCEEDS_THRESHOLD
            };
            
            // Update last valid price
            let breaker_mut = borrow_global_mut<CircuitBreaker>(@staking);
            breaker_mut.last_valid_price = current_price;
        } else {
            // Initialize last valid price
            let breaker_mut = borrow_global_mut<CircuitBreaker>(@staking);
            breaker_mut.last_valid_price = oracle::get_apt_price();
        };
    }

    public entry fun emergency_pause(admin: &signer, duration_secs: u64) acquires CircuitBreaker {
        let admin_addr = signer::address_of(admin);
        let breaker = borrow_global<CircuitBreaker>(@staking);
        
        assert!(admin_addr == breaker.admin, EUNAUTHORIZED);
        
        let breaker_mut = borrow_global_mut<CircuitBreaker>(@staking);
        breaker_mut.is_paused = true;
        breaker_mut.pause_until_timestamp = timestamp::now_seconds() + duration_secs;
    }

    public entry fun set_max_price_change_pct(admin: &signer, max_price_change_pct: u64) acquires CircuitBreaker {
        let admin_addr = signer::address_of(admin);
        let breaker = borrow_global<CircuitBreaker>(@staking);
        
        assert!(admin_addr == breaker.admin, EUNAUTHORIZED);
        
        let breaker_mut = borrow_global_mut<CircuitBreaker>(@staking);
        breaker_mut.max_price_change_pct = max_price_change_pct;
    }
}
```

### 2. Time-Weighted Average Price (TWAP)

For high-value operations, using a TWAP instead of spot price can mitigate short-term price manipulation:

```move
module staking::twap {
    use aptos_framework::timestamp;
    use staking::oracle;
    use std::vector;

    struct PricePoint has store {
        price: u128,
        timestamp: u64,
    }

    struct TWAPConfig has key {
        price_history: vector<PricePoint>,
        max_history_length: u64,
    }

    fun init_module(staking_signer: &signer) {
        move_to(staking_signer, TWAPConfig {
            price_history: vector::empty<PricePoint>(),
            max_history_length: 10, // Keep last 10 price points
        });
    }

    public fun update_price_history() acquires TWAPConfig {
        let config = borrow_global_mut<TWAPConfig>(@staking);
        
        // Add new price point
        vector::push_back(&mut config.price_history, PricePoint {
            price: oracle::get_apt_price(),
            timestamp: timestamp::now_seconds(),
        });
        
        // Remove oldest price point if we exceed max length
        if (vector::length(&config.price_history) > config.max_history_length) {
            vector::remove(&mut config.price_history, 0);
        };
    }

    public fun get_twap(duration_secs: u64): u128 acquires TWAPConfig {
        let config = borrow_global<TWAPConfig>(@staking);
        let current_time = timestamp::now_seconds();
        let cutoff_time = current_time - duration_secs;
        
        let total_price: u128 = 0;
        let total_weight: u64 = 0;
        
        let i = vector::length(&config.price_history);
        while (i > 0) {
            i = i - 1;
            let price_point = vector::borrow(&config.price_history, i);
            
            if (price_point.timestamp >= cutoff_time) {
                // Simple average for now, could be enhanced with time-weighted calculations
                total_price = total_price + price_point.price;
                total_weight = total_weight + 1;
            };
        };
        
        if (total_weight == 0) {
            // Fallback to current price if no historical data in range
            oracle::get_apt_price()
        } else {
            total_price / (total_weight as u128)
        }
    }
}
```

### 3. Confidence Interval Checks

Rejecting prices with high confidence intervals can prevent using uncertain price data:

```move
module staking::confidence_check {
    use pyth::price;
    use pyth::price_identifier;
    use pyth::pyth;
    use pyth::i64;
    use staking::oracle;

    const PYTH_APT_ID: vector<u8> = x"03ae4db29ed4ae33d323568895aa00337e658e348b37509f5372ae51f0af00d5";
    const MAX_CONFIDENCE_PCT: u64 = 5; // 5% maximum confidence interval as percentage of price

    public fun is_price_reliable(max_age_secs: u64): bool {
        let price_data = pyth::get_price_no_older_than(price_identifier::from_byte_vec(PYTH_APT_ID), max_age_secs);
        
        let conf = price::get_conf(&price_data);
        let price_val = i64::get_magnitude_if_positive(&price::get_price(&price_data));
        
        // Calculate confidence as percentage of price
        let conf_pct = (conf * 100) / price_val;
        
        // Reject if confidence interval > MAX_CONFIDENCE_PCT% of price
        conf_pct <= MAX_CONFIDENCE_PCT
    }
}
```

### 4. Fallback Price Mechanisms

Implementing fallback mechanisms ensures your contract can continue operating even if the primary oracle is unavailable:

```move
module staking::fallback_price {
    use aptos_framework::timestamp;
    use staking::oracle;

    struct PriceCache has key {
        last_valid_price: u128,
        last_update_time: u64,
        max_cache_age_secs: u64,
    }

    fun init_module(staking_signer: &signer) {
        move_to(staking_signer, PriceCache {
            last_valid_price: 0,
            last_update_time: 0,
            max_cache_age_secs: 3600, // 1 hour default
        });
    }

    public fun get_price_with_fallback(): u128 acquires PriceCache {
        let cache = borrow_global<PriceCache>(@staking);
        let current_time = timestamp::now_seconds();
        
        // Try to get fresh price
        let fresh_price = oracle::get_apt_price();
        
        // Update cache
        let cache_mut = borrow_global_mut<PriceCache>(@staking);
        cache_mut.last_valid_price = fresh_price;
        cache_mut.last_update_time = current_time;
        
        fresh_price
    }

    public fun get_price_with_fallback_safe(): u128 acquires PriceCache {
        let cache = borrow_global<PriceCache>(@staking);
        let current_time = timestamp::now_seconds();
        
        // Try to get fresh price, but don't abort if it fails
        let fresh_price_opt = get_fresh_price_safe();
        
        if (fresh_price_opt.is_some) {
            // Update cache with fresh price
            let cache_mut = borrow_global_mut<PriceCache>(@staking);
            cache_mut.last_valid_price = fresh_price_opt.value;
            cache_mut.last_update_time = current_time;
            fresh_price_opt.value
        } else if (cache.last_valid_price > 0 && 
                  current_time - cache.last_update_time <= cache.max_cache_age_secs) {
            // Return cached price if not too old
            cache.last_valid_price
        } else {
            // No valid price available
            abort 1
        }
    }

    struct Option<T> has copy, drop, store {
        is_some: bool,
        value: T,
    }

    fun get_fresh_price_safe(): Option<u128> {
        // This is a simplified example - in a real implementation, you would need to
        // catch the abort from oracle::get_apt_price() which requires more complex error handling
        // than is shown here
        Option<u128> { is_some: true, value: oracle::get_apt_price() }
    }
}
```

## Integration with Commission Contract

To integrate these security enhancements with the commission contract, modify the `distribute_commission` function:

```move
public entry fun distribute_commission() acquires CommissionConfig, CommissionEvents {
    // Check circuit breaker first
    circuit_breaker::check_circuit_breaker();
    
    // Check price confidence
    assert!(confidence_check::is_price_reliable(120), EUNRELIABLE_PRICE);
    
    // For high-value operations, use TWAP instead of spot price
    twap::update_price_history();
    let apt_price = twap::get_twap(3600); // 1-hour TWAP
    
    // Rest of the function remains the same...
}
```

## Security Checklist

When implementing oracle integrations, follow this security checklist:

1. **Price Staleness**
   - [x] Implement maximum age checks for price data
   - [x] Have fallback mechanisms for stale prices

2. **Price Manipulation Protection**
   - [x] Use TWAP for high-value operations
   - [x] Implement circuit breakers for suspicious price movements
   - [x] Check confidence intervals

3. **Error Handling**
   - [x] Gracefully handle oracle failures
   - [x] Implement fallback mechanisms
   - [x] Track and limit debt accumulation

4. **Access Control**
   - [x] Restrict administrative functions to authorized addresses
   - [x] Implement timelock mechanisms for sensitive parameter changes

5. **Monitoring and Alerts**
   - [x] Emit events for important state changes
   - [x] Log price anomalies
   - [x] Track commission debt

## Next Steps

Now that you've learned about security best practices, proceed to [Testing and Deployment](./06-testing-deployment.md) to learn how to test and deploy your oracle integration.