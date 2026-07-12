# Submission — KolaForm

- **Repo:** https://github.com/<you>/KolaForm  <!-- TODO: replace -->
- **Passing CI run:** <link to green Actions run>  <!-- TODO: replace -->

## Write-up (200 words)

KolaForm provisions a locked-down Azure data platform from a single `git
push`: an ADLS Gen2 data lake, a private Azure Container Instance, and
layered network controls — an NSG, a default-deny storage firewall admitting
only the compute subnet, and managed-identity RBAC. On boot, the container
authenticates with its identity and writes a heartbeat blob into the lake,
so every deploy proves the full chain works. There are no credentials
anywhere: GitHub OIDC federation replaces client secrets, storage account
keys are disabled outright, and the three repo "secrets" are plain
identifiers.

I split the Terraform into `network`, `data`, and `compute` modules because
that mirrors the trust boundary: the network module exports one subnet id,
and both other modules treat it as their only door. The root module owns
naming and wiring, so a fork reproduces everything from three variables.

What I got wrong first: I locked the storage firewall down and immediately
locked Terraform itself out — the GitHub runner could no longer manage the
blob container. The fix: the pipeline temporarily allowlists the runner's
IP, removes it in an `always()` step, and `ignore_changes` on `ip_rules`
keeps that from ever appearing as drift.
