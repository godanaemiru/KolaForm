# KolaForm — Zero-Click Cloud Deploy

Complete Azure data infrastructure provisioned by Terraform and deployed by
GitHub Actions on every push to `main`. No console clicks, no stored
credentials, reproducible from this repo alone.

## What gets deployed

```
┌─────────────────────────── kolaform-rg ────────────────────────────┐
│                                                                    │
│  kolaform-vnet (10.20.0.0/16)                                      │
│  ┌───────────── compute subnet (10.20.1.0/24) ─────────────┐       │
│  │  NSG: VNet-only inbound, deny Internet                  │       │
│  │  ┌────────────────────────────┐                         │       │
│  │  │ ACI: kolaform-worker       │   Microsoft.Storage     │       │
│  │  │ private IP, no public IP   │──── service endpoint ─┐ │       │
│  │  │ user-assigned identity     │                       │ │       │
│  │  └────────────────────────────┘                       │ │       │
│  └───────────────────────────────────────────────────────┼─┘       │
│                                                          ▼         │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │ kfdata<suffix> — ADLS Gen2 data lake                     │      │
│  │ firewall: default DENY, allow compute subnet only        │      │
│  │ shared keys DISABLED — Entra ID auth only                │      │
│  │ RBAC: worker identity = Storage Blob Data Contributor    │      │
│  └──────────────────────────────────────────────────────────┘      │
└────────────────────────────────────────────────────────────────────┘
```

- **Data layer** — ADLS Gen2 storage account (hierarchical namespace), blob
  container `data`, storage keys disabled, TLS 1.2+, no public blob access.
- **Compute layer** — Azure Container Instance on a private IP inside a
  delegated subnet. On boot it logs in with its managed identity and writes a
  heartbeat blob into the lake — living proof the whole chain works.
- **Access controls** — NSG (VNet-only inbound), storage firewall
  (default deny, compute subnet allowed via service endpoint), and RBAC via
  managed identity. No connection strings, no keys, anywhere.
- **State** — remote backend in a dedicated Azure Storage account, accessed
  with Entra ID auth (`use_azuread_auth`), shared keys disabled there too.

## Reproduce it in under 10 minutes

1. **Fork** this repo.
2. **Bootstrap** (the only manual step, ~2 min) — open
   [Azure Cloud Shell](https://shell.azure.com) (bash) and run:

   ```bash
   git clone https://github.com/<you>/KolaForm && cd KolaForm/bootstrap
   GITHUB_REPO=<you>/KolaForm ./bootstrap.sh
   ```

   This creates the remote-state storage account, an Entra ID app with
   **GitHub OIDC federated credentials** (no client secret exists at all),
   and the role assignments the pipeline needs. It prints three values.
3. **Set three secrets** in your fork
   (Settings → Secrets and variables → Actions):
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.
   These are identifiers, not credentials — auth is a per-run OIDC token
   exchange, so there is nothing to leak or rotate.
4. **Push to `main`** (or re-run the `deploy` workflow). Watch Actions run
   fmt → validate → plan → apply. Done.

Pull requests get a `terraform plan` only; `apply` runs exclusively on push
to `main`.

## Design notes

- **Zero secrets by construction.** OIDC federation means no client secret is
  ever created. The state account name is *derived* from the subscription id
  (`tfstate` + first 10 hex of its SHA-256) by both `bootstrap.sh` and the
  workflow, so exactly three repo secrets suffice — no backend config secret.
- **Locked-down storage vs. Terraform's data plane.** The data account denies
  all traffic by default, but Terraform on a GitHub runner must still manage
  the blob container. Two defenses: the container is referenced by
  `storage_account_id`, so the provider manages it via the management plane;
  and the pipeline temporarily allowlists the runner's IP, removing it in an
  `always()` step (`ip_rules` are in `ignore_changes` so this never drifts).
- **User-assigned identity** for the worker, so the RBAC grant exists before
  the container first boots (system-assigned would race its own role
  assignment).

## Verifying the deployment

After a green run, the heartbeat proves end-to-end wiring:

```bash
az container logs -g kolaform-rg -n kolaform-worker   # "heartbeat uploaded"
az storage blob list --account-name <storage_account output> \
  --container-name data --prefix heartbeats/ --auth-mode login -o table
```

(Blob listing must come from an allowed network — run it from Cloud Shell
after temporarily adding your IP, or trust the container logs.)

## Teardown

Run the `destroy` workflow (Actions → destroy → Run workflow → type
`destroy`). State backend and app registration are kept; remove them with
`az group delete -n kolaform-tfstate-rg` and
`az ad app delete --id <AZURE_CLIENT_ID>` if you want a full clean-up.

## Repo layout

```
infra/                  Terraform root module
  modules/network/      VNet, delegated subnet, NSG
  modules/data/         ADLS Gen2 account, container, firewall rules
  modules/compute/      managed identity, RBAC, container instance
.github/workflows/      deploy.yml (plan/apply), destroy.yml (manual)
bootstrap/bootstrap.sh  one-time OIDC + state backend setup (Cloud Shell)
```

## Costs

Everything is pay-per-use or pennies: LRS storage, a 0.5 vCPU container that
runs for seconds, and free-tier networking. Tear down with the destroy
workflow when done.
