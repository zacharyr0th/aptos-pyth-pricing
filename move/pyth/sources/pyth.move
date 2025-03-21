/// This module serves as an interface to the Pyth Network price oracle.
/// All functions abort as they are meant to be implemented by the actual Pyth contract.
/// This interface allows us to compile against Pyth's API without including the full implementation.
module pyth::pyth {
    use pyth::price_identifier::PriceIdentifier;
    use pyth::price::Price;

    public fun get_price(_price_identifier: &PriceIdentifier): Price {
        abort 0
    }

    public fun get_price_no_older_than(_price_identifier: PriceIdentifier, _max_age_secs: u64): Price {
        abort 0
    }

    public fun get_price_unsafe(_price_identifier: &PriceIdentifier): Price {
        abort 0
    }
}
