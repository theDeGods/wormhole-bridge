//anchor_spl has a (non-documentated) feature by the name of mpl-token-metadata
// which wraps Metaplex Metadata accounts but it's try_deserialize function is implemented
// incorrectly because it doesn't check that the metadata has actually been initialized!
//Hence, we're rolling our own here.

use anchor_lang::prelude::*;
use mpl_token_metadata::{
  ID as METADATA_ID,
  state::{PREFIX, Metadata as MplMetadata, TokenMetadataAccount}
};

#[derive(Debug, Clone)]
pub struct Program;

impl Id for Program {
  fn id() -> Pubkey {
    METADATA_ID
  }
}

#[derive(Clone)]
pub struct Metadata(MplMetadata);

impl Metadata {
  pub const SEED_PREFIX: &'static [u8] = PREFIX.as_bytes();
  pub const LEN: usize = mpl_token_metadata::state::MAX_METADATA_LEN;
}

impl AccountDeserialize for Metadata {
  fn try_deserialize(buf: &mut &[u8]) -> Result<Self> {
    let md = Self::try_deserialize_unchecked(buf)?;
    if md.key != MplMetadata::key() {
      return Err(ErrorCode::AccountDiscriminatorMismatch.into());
    }
    Ok(md)
  }

  fn try_deserialize_unchecked(buf: &mut &[u8]) -> Result<Self> {
    Ok(Self(MplMetadata::deserialize(buf)?))
  }
}

//no-op since data can only be changed through metaplex's metadata program
impl AccountSerialize for Metadata {}

impl Owner for Metadata {
  fn owner() -> Pubkey {
    METADATA_ID
  }
}

impl std::ops::Deref for Metadata {
  type Target = MplMetadata;

  fn deref(&self) -> &Self::Target {
    &self.0
  }
}