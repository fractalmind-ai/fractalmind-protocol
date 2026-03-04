/// FractalMind Protocol — Bootstrap
/// One-Time Witness pattern: creates ProtocolRegistry at publish.
module fractalmind_protocol::bootstrap {
    use sui::tx_context::TxContext;

    use fractalmind_protocol::organization;

    /// OTW — must be uppercase module name.
    public struct BOOTSTRAP has drop {}

    fun init(_witness: BOOTSTRAP, ctx: &mut TxContext) {
        organization::create_and_share_registry(ctx);
    }
}
