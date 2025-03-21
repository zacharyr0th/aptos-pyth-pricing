# Part 2: Commission Contract Implementation

> 🎯 **Purpose**: This guide explains how to implement a commission contract that uses the oracle module to convert between USD and APT for payments.

[← Back to Oracle Implementation](./03-oracle-implementation.md) | [Next: Security Best Practices →](./04-security-best-practices.md)

---

## 📋 Overview

The commission contract ([`commission.move`](../move/staking/sources/commission.move)) enables USD-denominated payments using APT tokens. It manages:

- 💵 USD-denominated yearly commission rates
- 🔄 Automatic USD/APT conversion using oracle prices
- 📊 Commission distribution between manager and operator
- 💰 Debt tracking for insufficient balances

## 🔑 Key Components

### ⚙️ Configuration Storage

| Field | Type | Purpose |
|:------|:----:|---------|
| `manager` | `address` | Can set commission rate |
| `operator` | `address` | Receives commission payments |
| `yearly_commission_amount` | `u64` | Annual commission in USD |
| `signer_cap` | `SignerCapability` | Resource account capability |
| `last_update_secs` | `u64` | Timestamp of last update |
| `commission_debt` | `u64` | Unpaid commission in USD |

### 📢 Event Tracking

> 💡 **Note**: Events help track commission distribution and debt changes.

```move
#[event]
struct CommissionDistributed has drop, store {
    manager: address,
    operator: address,
    usd_price: u128,
    commission_amount_apt: u64,
    manager_amount_apt: u64,
    commission_debt_usd: u64
}
```

### 🛠️ Core Functions

1. **Commission Calculation**
   > 📊 Calculates owed commission based on time passed
   ```move
   public fun commission_owed(): u64 {
       let seconds_passed = now_secs - config.last_update_secs;
       math64::mul_div(
           seconds_passed, 
           config.yearly_commission_amount, 
           ONE_YEAR_IN_SECONDS
       ) + config.commission_debt
   }
   ```

2. **Currency Conversion**
   > 💱 Converts between USD and APT using oracle prices
   ```move
   inline fun usd_to_apt(usd_amount: u64): u64 {
       let apt_price = oracle::get_apt_price();
       math128::mul_div(
           (usd_amount as u128) * OCTAS_IN_ONE_APT, 
           oracle::precision(), 
           apt_price
       ) as u64
   }
   ```

3. **Distribution Logic**
   > 📤 Handles commission payments and debt tracking
   ```move
   public entry fun distribute_commission(account: &signer) {
       let commission_in_apt = commission_owed_in_apt();
       let balance = coin::balance<AptosCoin>(@staking);
       
       if (balance <= commission_in_apt) {
           // Track unpaid amount as debt
           config.commission_debt = apt_to_usd(commission_in_apt - balance);
       } else {
           // Pay commission and send surplus to manager
           transfer_commission(commission_in_apt, balance);
       }
   }
   ```

## ⚠️ Important Considerations

1. **🔢 Precision Handling**
   - All USD amounts use 8 decimal places (1e8)
   - Small rounding errors (1 octa) may occur during conversion
   - Debt tracking preserves value across price changes

2. **🔐 Access Control**
   ```move
   inline fun assert_manager_or_operator(account: &signer) {
       assert!(
           account_addr == config.manager || 
           account_addr == config.operator, 
           EUNAUTHORIZED
       );
   }
   ```

3. **💳 Debt Management**
   - Tracks unpaid commission in USD
   - Automatically attempts repayment in future distributions
   - Preserves value regardless of APT price fluctuations

## 🧪 Testing

> 🔍 **Testing Tip**: Always test edge cases and debt scenarios.

```move
#[test]
fun test_distribute_commission() {
    // Set test price and mint coins
    oracle::set_test_price(100000000); // $1.00
    let coins = coin::mint<AptosCoin>(100000000);
    
    // Test distribution
    commission::distribute_commission(&operator);
    assert!(coin::balance<AptosCoin>(@operator) > 0, 0);
}
```

---

## ⏭️ Next Steps

Proceed to [Security Best Practices](./04-security-best-practices.md) to learn about securing your implementation. 