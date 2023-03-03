use anchor_lang::prelude::*;

#[cfg(feature = "mainnet")]
declare_id!("worm2ZoG2kUd4vFXhvjh93UUH596ayRfgQ2MgjNMTth");

#[cfg(feature = "solana-devnet")]
declare_id!("3u8hJUVTA4jH1wYAyUur7FFZVQ8H635K3tSHHF4ssjQ5");

#[cfg(feature = "tilt-devnet")]
declare_id!("Bridge1p5gheXUvJ6jGWGeCsgPKgnE3YgdGKRVCMY9o");

#[derive(Debug, Clone)]
pub struct Wormhole;

impl Id for Wormhole {
    fn id() -> Pubkey {
        ID
    }
}
