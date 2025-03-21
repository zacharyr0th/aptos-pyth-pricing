#[test_only]
module pyth::pyth_tests {
    use pyth::price_identifier;
    use pyth::pyth;

    // Test constants
    const PRICE_FEED_BTC: vector<u8> = x"ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace";
    const MAX_AGE: u64 = 60; // 60 seconds

    #[test]
    #[expected_failure(abort_code = 0, location = pyth::price_identifier)]
    fun test_price_identifier_from_byte_vec() {
        price_identifier::from_byte_vec(PRICE_FEED_BTC);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = pyth::price_identifier)]
    fun test_pyth_get_price() {
        let price_id = price_identifier::from_byte_vec(PRICE_FEED_BTC);
        pyth::get_price(&price_id);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = pyth::price_identifier)]
    fun test_pyth_get_price_no_older_than() {
        let price_id = price_identifier::from_byte_vec(PRICE_FEED_BTC);
        pyth::get_price_no_older_than(price_id, MAX_AGE);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = pyth::price_identifier)]
    fun test_pyth_get_price_unsafe() {
        let price_id = price_identifier::from_byte_vec(PRICE_FEED_BTC);
        pyth::get_price_unsafe(&price_id);
    }
} 