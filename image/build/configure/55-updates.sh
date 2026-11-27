# Online system updates (DECISIONS.md D36). Installed computers get new Kestrel images from
# $UPDATE_SOURCE (GitHub's container registry, built and signed by .github/workflows/image.yml)
# and accept only images signed with Kestrel's key, like Universal Blue does for its images.
source /tmp/build/lib.sh

[[ -n ${UPDATE_SOURCE:-} ]] || die "UPDATE_SOURCE not set (config.env)"
repo=${UPDATE_SOURCE%:*}
key=/etc/pki/containers/kestrel.pub
[[ -s $key ]] || die "Kestrel's public signing key $key missing"

# The installer points the new system at this (see image/live/build.sh), `kestrel update` too.
install -d /usr/share/kestrel
echo "$UPDATE_SOURCE" > /usr/share/kestrel/update-source

# Only images signed with Kestrel's key may be installed from there.
python3 - "$repo" "$key" <<'PY' || die "could not add Kestrel to the container signature policy"
import json, sys
repo, key = sys.argv[1:]
path = "/etc/containers/policy.json"
policy = json.load(open(path))
policy.setdefault("transports", {}).setdefault("docker", {})[repo] = [
    {"type": "sigstoreSigned", "keyPath": key, "signedIdentity": {"type": "matchRepository"}}]
json.dump(policy, open(path, "w"), indent=4)
PY
cat > /etc/containers/registries.d/kestrel.yaml <<YAML
# Kestrel's signatures are stored next to the image in the registry (DECISIONS.md D36).
docker:
  $repo:
    use-sigstore-attachments: true
YAML

# Discover shows system updates next to app updates and installs them with one click.
rpm -q plasma-discover-rpm-ostree >/dev/null || die "plasma-discover-rpm-ostree missing"

# Updates are downloaded in the background and take effect at the next restart (the base
# image's rpm-ostreed setting "stage"); check it is still that way.
grep -qx 'AutomaticUpdatePolicy=stage' /etc/rpm-ostreed.conf || die "automatic updates not set to 'stage'"
systemctl is-enabled -q rpm-ostreed-automatic.timer || die "automatic update timer not enabled"
