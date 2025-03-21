# Part 2: Oracle Implementation

> 🎯 **Purpose**: This guide walks through implementing the oracle module that interfaces with Pyth Network to fetch and normalize price data.

[← Back to Understanding Pyth](./01-understanding-pyth.md) | [Next: Commission Contract →](./02-commission-contract.md)

---

## 📋 Overview

The oracle module is responsible for:

- 📊 Fetching price data from Pyth Network
- 🔄 Normalizing the price to a standard precision
- 🔌 Providing a clean interface for other modules
- 🛡️ Implementing basic security features

## 🛠️ Implementation

The complete implementation can be found in [`oracle.move`](../move/staking/sources/oracle.move). Let's examine the key components:

### ⚙️ Configuration Constants

| Constant | Value | Description |
|:---------|:------:|-------------|
| `PRECISION` | 100000000 (1e8) | Standard precision for price normalization |
| `INITIAL_MAX_AGE_SECS` | 120 (2 minutes) | Maximum age allowed for price data |
| `PYTH_APT_ID` | 0x03ae4d... | Pyth price feed ID for APT/USD |

### ⚠️ Error Codes

| Error | Code | Description |
|:-------|:----:|-------------|
| `ESTALE_PRICE` | 1 | Price data is older than max_age_secs |

### 📝 Configuration

> 💡 **Note**: The configuration is stored on-chain and initialized during module deployment.

```move
struct OracleConfig has key {
    /// Maximum age of the price in seconds
    max_age_secs: u64,
}
```

### 🔄 Core Functionality

The main price fetching function:

```move
#[view]
public fun get_apt_price(): u128 acquires OracleConfig, TestPrice {
    let config = &OracleConfig[@staking];
    let price = pyth::get_price_no_older_than(
        price_identifier::from_byte_vec(PYTH_APT_ID), 
        config.max_age_secs
    );
    // ... price normalization ...
}
```

### 🧪 Testing Support

> 🔍 **Testing Tip**: Use the test-only functionality for simulating price updates in your tests.

```move
#[test_only]
struct TestPrice has key {
    price: u128,
}
```

---

## ⏭️ Next Steps

Proceed to [Commission Contract](./02-commission-contract.md) to learn how to use this price data in a practical application. 