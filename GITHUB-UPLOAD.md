# GitHub Upload - SIMHA AiOps 1.0.1 Final

Use Git, not browser drag/drop, so hidden `.github/` files and stale deletions are handled correctly.

```bash
cd /tmp
rm -rf aiops
git clone https://github.com/simhaonline/aiops.git

bash /path/to/SIMHA-AiOps-v1.0.1-FINAL/sync-github-repo.sh /tmp/aiops
cd /tmp/aiops

bash qa/finalize-release.sh
bash qa/validate-release.sh

git add -A
git status
git commit -m "Finalize SIMHA AiOps v1.0.1"
git push origin main
```

After GitHub shows the new commit, test the exact required bootstrap:

```bash
curl -fsSL https://raw.githubusercontent.com/simhaonline/aiops/main/install.sh | bash
```

The bootstrap resolves `main` to one immutable Git commit before downloading the checksum manifest and manager payloads.

For a tagged production install:

```bash
git tag -a v1.0.1 -m "SIMHA AiOps v1.0.1"
git push origin v1.0.1

curl -fsSL https://raw.githubusercontent.com/simhaonline/aiops/v1.0.1/install.sh \
  | AIOPS_REF=v1.0.1 AIOPS_REQUIRE_PIN=1 bash
```
