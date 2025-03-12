# Understanding Pyth Network

> Purpose: This guide explains the essential concepts of Pyth Network and its integration with Aptos.

## Core Concepts

### What is Pyth Network?

Pyth Network is a first-party oracle providing high-fidelity financial market data to blockchain applications. Key features:
- Sub-second price updates
- High confidence intervals
- Wide range of price feeds
- Cross-chain availability

### Price Feed Structure

```move
struct Price {
    price: I64,      // Price value
    conf: u64,       // Confidence interval
    expo: I64,       // Price scaling exponent
    timestamp: u64   // Publication timestamp
}
```

### Integration Points

1. **Price Fetching**
```move
let price = pyth::get_price_no_older_than(
    price_identifier::from_byte_vec(PRICE_FEED_ID), 
    max_age_secs
);
```

2. **Price Normalization**
```move
let normalized_price = math128::mul_div(
    (raw_price as u128),
    PRECISION,
    math128::pow(10, (i64::get_magnitude_if_negative(&expo) as u128))
);
```

## Security Considerations

1. **Price Staleness**
   - Always check timestamp freshness
   - Implement maximum age limits
   - Use fallback mechanisms

2. **Price Confidence**
   - Check confidence intervals
   - Reject prices with high uncertainty
   - Consider using TWAP for stability

3. **Circuit Breakers**
   - Monitor price movements
   - Pause on suspicious activity
   - Implement fallbacks

## Best Practices

1. **Price Validation**
   - Always validate before use
   - Check confidence intervals
   - Verify timestamps

2. **Error Handling**
   - Handle stale prices gracefully
   - Implement fallback mechanisms
   - Log validation failures

3. **Gas Optimization**
   - Cache prices when appropriate
   - Batch updates when possible
   - Use efficient math operations

## Next Steps

Proceed to [Core Implementation](./03-oracle-implementation.md) to implement the oracle module. 