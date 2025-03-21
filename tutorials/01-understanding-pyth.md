# Part 1: Understanding Pyth Network

> 🎯 **Purpose**: This guide explains the essential concepts of Pyth Network and its integration with Aptos.

[← Back to Index](../README.md) | [Next: Oracle Implementation →](./03-oracle-implementation.md)

---

## 🌟 Core Concepts

### What is Pyth Network?

Pyth Network is a first-party oracle providing high-fidelity financial market data to blockchain applications. 

### 📚 Interface Overview

The Pyth integration consists of three main interface modules, all found in the [`move/pyth/sources`](../move/pyth/sources) directory:

| Module | Purpose | Key Structures |
|:------:|---------|----------------|
| [`price.move`](../move/pyth/sources/price.move) | Price data structures | `Price { price: I64, conf: u64, expo: I64, timestamp: u64 }` |
| [`i64.move`](../move/pyth/sources/i64.move) | Signed integer support | `I64 { negative: bool, magnitude: u64 }` |
| [`pyth.move`](../move/pyth/sources/pyth.move) | Core oracle interface | `get_price_no_older_than(price_id: PriceIdentifier, max_age: u64): Price` |

### 🔑 Price Feed Identifiers

Price feeds are identified using the [`price_identifier.move`](../move/pyth/sources/price_identifier.move) module:

Source: [`move/pyth/sources/price_identifier.move`](../move/pyth/sources/price_identifier.move)
```move
/// This module provides functionality for working with Pyth price feed identifiers.
module pyth::price_identifier {
    struct PriceIdentifier has copy, drop, store {
        bytes: vector<u8>    // 32-byte unique identifier
    }

    /// Creates a PriceIdentifier from a byte vector
    public fun from_byte_vec(_bytes: vector<u8>): PriceIdentifier {
        abort 0
    }
}
```

Example usage:
Source: [`move/pyth/sources/price_identifier.move`](../move/pyth/sources/price_identifier.move)
```move
// APT/USD price feed
const PYTH_APT_ID: vector<u8> = x"03ae4db29ed4ae33d323568895aa00337e658e348b37509f5372ae51f0af00d5";

// Convert to PriceIdentifier
let id = price_identifier::from_byte_vec(PYTH_APT_ID);
```

> 💡 **Tip**: Always use constants for price feed IDs to ensure consistency and prevent typos.

### 🔄 Integration Steps

1. **Fetch Price Data**
Source: [`move/pyth/sources/pyth.move`](../move/pyth/sources/pyth.move)
```move
let price = pyth::get_price_no_older_than(price_id, max_age_secs);
```

2. **Access Price Components**
Source: [`move/pyth/sources/price.move`](../move/pyth/sources/price.move)
```move
let raw_price = price::get_price(&price);     // Current price
let confidence = price::get_conf(&price);      // Confidence interval
let exponent = price::get_expo(&price);       // Decimal exponent
let timestamp = price::get_timestamp(&price);  // Update timestamp
```

For complete implementation details of these interfaces, refer to the source files in the [`move/pyth/sources`](../move/pyth/sources) directory.

---

## ⏭️ Next Steps

Proceed to [Oracle Implementation](./03-oracle-implementation.md) to learn how to build on top of these interfaces. 