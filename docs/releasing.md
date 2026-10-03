# Releasing scoop

## One-time setup (already done for this repo)

1. `scripts/make-signing-cert.sh` creates `~/TextGrabSigning/` (the certificate, private key, and password).
2. **Back up `~/TextGrabSigning/`** somewhere safe (a password manager or an encrypted drive). If it's lost, the next release has a different code identity and every teammate has to grant Screen Recording (and, for Smart Paste, Accessibility) permission again.
3. In GitHub → Settings → Environments, create an environment named `signing`. Under **Deployment branches and tags**, choose **Selected branches and tags** and add the branch `main` and the tag pattern `v*.*.*`. Only CI on `main` and the Release workflow can then read the signing secrets. Repo-level secrets would be readable by any pull request branch.
4. Add the secrets to that environment (not to the repo):

   ```bash
   base64 -i ~/TextGrabSigning/TextGrabSigning.p12 | gh secret set SIGNING_CERT_P12_BASE64 --env signing --repo bryantworks/scoop
   gh secret set SIGNING_CERT_PASSWORD --env signing --repo bryantworks/scoop < ~/TextGrabSigning/password.txt
   ```

## Cutting a release

1. Make sure `main` is green in CI and run through `docs/testing.md`. You can install the `TextGrab-ci-*` artifact from the latest `main` CI run for this.
2. Tag and push:

   ```bash
   git switch main && git pull
   git tag v1.2.3
   git push origin v1.2.3
   ```

   Tag only a commit that is on `main`. The Release workflow stops if the tagged commit hasn't been merged.

3. The **Release** workflow tests, builds a universal signed app, and publishes a GitHub Release with `TextGrab.zip` and `TextGrab.zip.sha256`. The install command always fetches the latest release.
4. Tell teammates to re-run the install command to update.

Use semantic versions: bump the patch number for fixes, the minor number for features.

## If a release is bad

Delete the release and tag (`gh release delete v1.2.3 --cleanup-tag`). The install command then falls back to the previous latest release. Fix the problem through a PR, then tag a new version.
