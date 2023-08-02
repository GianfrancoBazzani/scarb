use anyhow::Result;

use scarb::core::Config;
use scarb::ops;

#[tracing::instrument(skip_all, level = "info")]
pub fn run(config: &Config) -> Result<()> {
    let ws = ops::read_workspace(config.manifest_path(), config)?;

    match ops::resolve_workspace(&ws) {
        Ok(_) => Ok(()),
        Err(e) => Err(e),
    }
}
