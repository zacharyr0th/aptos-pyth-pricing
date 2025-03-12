# Oracle Implementation

> Purpose: This guide walks through implementing the oracle module that interfaces with Pyth Network to fetch and normalize price data.

## Common Utilities

First, let's create a utilities module that will be shared across our implementation:

```move
module staking::utils {
    use aptos_framework::timestamp;

    /// Generic Option type to avoid reimplementing it in multiple modules
    struct Option<T> has copy, drop, store {
        is_some: bool,
        value: T,
    }

    /// Common price-related utilities
    public fun calculate_price_change_pct(price1: u128, price2: u128): u64 {
        let change = if (price1 > price2) {
            ((price1 - price2) * 100) / price2
        } else {
            ((price2 - price1) * 100) / price1
        };
        (change as u64)
    }

    /// Common time-based checks
    public fun is_stale(last_update: u64, max_age: u64): bool {
        timestamp::now_seconds() - last_update > max_age
    }

    /// Common math utilities
    public fun safe_mul_div(a: u128, b: u128, c: u128): u128 {
        // Compute (a * b) / c with overflow checks
        let product = (a as u256) * (b as u256);
        ((product / (c as u256)) as u128)
    }
}
```

## Oracle Implementation

## Overview

The oracle module is responsible for:
1. Fetching price data from Pyth Network
2. Normalizing the price to a standard precision
3. Providing a clean interface for other modules to access price data
4. Implementing basic security features like staleness checks

## Implementation Steps

Let's create the `oracle.move` file in the `staking/sources` directory:

```move
/// Module used to read the price of APT from the oracle.
///
/// Note that this is the bare minimum implementation of the oracle module. More controls beyond price staleness check
/// can be added and developers using this module should consider various security and economic implications when using
/// this oracle in their protocols.
module staking::oracle {
    use aptos_std::math128;
    use pyth::i64;
    use pyth::price;
    use pyth::price_identifier;
    use pyth::pyth;

    const PRECISION: u128 = 100000000; // 1e8
    const INITIAL_MAX_AGE_SECS: u64 = 120; // 2 minutes
    const PYTH_APT_ID: vector<u8> = x"03ae4db29ed4ae33d323568895aa00337e658e348b37509f5372ae51f0af00d5";

    /// Price read from oracle is stale
    const ESTALE_PRICE: u64 = 1;

    struct OracleConfig has key {
        /// Maximum age of the price in seconds. If the price is older than this, reading the price will fail.
        max_age_secs: u64,
    }

    fun init_module(staking_signer: &signer) {
        move_to(staking_signer, OracleConfig {
            max_age_secs: INITIAL_MAX_AGE_SECS,
        });
    }

    #[view]
    public fun get_apt_price(): u128 acquires OracleConfig, TestPrice {
        if (exists<TestPrice>(@staking)) {
            return TestPrice[@staking].price;
        };

        let config = &OracleConfig[@staking];
        let price = pyth::get_price_no_older_than(price_identifier::from_byte_vec(PYTH_APT_ID), config.max_age_secs);
        let raw_price = i64::get_magnitude_if_positive(&price::get_price(&price));
        let expo = price::get_expo(&price);
        // Standardize precision or otherwise we'll get different magnitudes for different decimals
        math128::mul_div(
            (raw_price as u128),
            PRECISION,
            math128::pow(10, (i64::get_magnitude_if_negative(&expo) as u128)),
        )
    }

    public inline fun precision(): u128 {
        PRECISION
    }

    #[test_only]
    use aptos_framework::account;

    // This struct is used to test the commission contract only and will not be used in production.
    struct TestPrice has key {
        price: u128,
    }

    #[test_only]
    public fun set_test_price(price: u128) acquires TestPrice {
        if (exists<TestPrice>(@staking)) {
            TestPrice[@staking].price = price;
        } else {
            move_to(&account::create_signer_for_test(@staking), TestPrice { price });
        }
    }
}
```

## Code Explanation

Let's break down the key components of this module:

### Constants

```move
const PRECISION: u128 = 100000000; // 1e8
const INITIAL_MAX_AGE_SECS: u64 = 120; // 2 minutes
const PYTH_APT_ID: vector<u8> = x"03ae4db29ed4ae33d323568895aa00337e658e348b37509f5372ae51f0af00d5";
```

- `PRECISION`: Defines the standard precision for normalized prices (1e8)
- `INITIAL_MAX_AGE_SECS`: Maximum age of price data (2 minutes)
- `PYTH_APT_ID`: The Pyth price feed ID for APT/USD

### OracleConfig

```move
struct OracleConfig has key {
    /// Maximum age of the price in seconds. If the price is older than this, reading the price will fail.
    max_age_secs: u64,
}
```

This struct stores the configuration for the oracle, specifically the maximum age of price data.

### Initialization

```move
fun init_module(staking_signer: &signer) {
    move_to(staking_signer, OracleConfig {
        max_age_secs: INITIAL_MAX_AGE_SECS,
    });
}
```

The `init_module` function initializes the oracle configuration with the default maximum age.

### Price Fetching

```move
#[view]
public fun get_apt_price(): u128 acquires OracleConfig, TestPrice {
    if (exists<TestPrice>(@staking)) {
        return TestPrice[@staking].price;
    };

    let config = &OracleConfig[@staking];
    let price = pyth::get_price_no_older_than(price_identifier::from_byte_vec(PYTH_APT_ID), config.max_age_secs);
    let raw_price = i64::get_magnitude_if_positive(&price::get_price(&price));
    let expo = price::get_expo(&price);
    // Standardize precision or otherwise we'll get different magnitudes for different decimals
    math128::mul_div(
        (raw_price as u128),
        PRECISION,
        math128::pow(10, (i64::get_magnitude_if_negative(&expo) as u128)),
    )
}
```

The `get_apt_price` function:
1. Checks if a test price exists (for testing purposes)
2. Fetches the price from Pyth using `get_price_no_older_than`
3. Extracts the raw price and exponent
4. Normalizes the price to the standard precision

### Testing Support

```move
#[test_only]
struct TestPrice has key {
    price: u128,
}

#[test_only]
public fun set_test_price(price: u128) acquires TestPrice {
    if (exists<TestPrice>(@staking)) {
        TestPrice[@staking].price = price;
    } else {
        move_to(&account::create_signer_for_test(@staking), TestPrice { price });
    }
}
```

These functions and structs are used for testing purposes, allowing us to set a test price without relying on the actual Pyth Network.

## Enhancing the Oracle Module

While the basic implementation works, here are some enhancements you might consider:

### 1. Confidence Interval Checks

```move
public fun is_price_reliable(max_confidence_pct: u64): bool acquires OracleConfig {
    let config = &OracleConfig[@staking];
    let price_data = pyth::get_price_no_older_than(price_identifier::from_byte_vec(PYTH_APT_ID), config.max_age_secs);
    
    let conf = price::get_conf(&price_data);
    let price_val = i64::get_magnitude_if_positive(&price::get_price(&price_data));
    
    // Reject if confidence interval > X% of price
    conf <= (price_val * max_confidence_pct) / 100
}
```

### 2. Price Caching

```move
struct PriceCache has key {
    price: u128,
    last_update_time: u64,
}

public fun get_cached_price(max_cache_age_secs: u64): u128 acquires PriceCache, OracleConfig {
    let current_time = timestamp::now_seconds();
    
    if (exists<PriceCache>(@staking)) {
        let cache = borrow_global<PriceCache>(@staking);
        if (current_time - cache.last_update_time <= max_cache_age_secs) {
            return cache.price;
        }
    };
    
    // Get fresh price
    let fresh_price = get_apt_price();
    
    // Update cache
    if (exists<PriceCache>(@staking)) {
        let cache = borrow_global_mut<PriceCache>(@staking);
        cache.price = fresh_price;
        cache.last_update_time = current_time;
    } else {
        move_to(staking_signer, PriceCache {
            price: fresh_price,
            last_update_time: current_time,
        });
    };
    
    fresh_price
}
```

## Next Steps

Now that you have implemented the oracle module, proceed to [Commission Contract](./04-commission-contract.md) to learn how to use this price data in a practical application. 