# Wine's own Windows DLLs must carry the SELinux type for libraries that patch their own code
# (textrel_shlib_t), like Fedora's policy gives them under /usr/lib/wine (DECISIONS.md D29).
# Fedora 44's wine installs them under /usr/lib*/wine-wow64/wine, which the policy does not
# know, so they get the plain library type. On a classic install that still works; on the
# image's composefs root the kernel also checks the mount's own rights, and those may not
# patch plain libraries: every 32-bit Windows program crashed at its first instruction.
source /tmp/build/lib.sh

cil=$(mktemp -d)/kestrel-wine.cil
# Paths written out in full: SELinux uses the most specific matching rule, and a pattern like
# /usr/lib(64)? counts as less specific than the general /usr/lib rules, so it would lose.
cat > "$cil" <<'EOF'
(filecon "/usr/lib/wine-wow64/wine/[^/]+-windows/.+" file (system_u object_r textrel_shlib_t ((s0) (s0))))
(filecon "/usr/lib/wine-wow64/wine/[^/]+-unix/.+\.so" file (system_u object_r textrel_shlib_t ((s0) (s0))))
(filecon "/usr/lib64/wine-wow64/wine/[^/]+-windows/.+" file (system_u object_r textrel_shlib_t ((s0) (s0))))
(filecon "/usr/lib64/wine-wow64/wine/[^/]+-unix/.+\.so" file (system_u object_r textrel_shlib_t ((s0) (s0))))
EOF
semodule -i "$cil" || die "could not install the Kestrel Wine SELinux module"
rm -rf "${cil%/*}"
dll=$(grep -m1 '/i386-windows/ntdll\.dll$' < <(rpm -ql wine-core.i686)) || die "32-bit Wine not installed"
[[ $(matchpathcon -n "$dll") == *:textrel_shlib_t:* ]] || die "Wine DLLs would not get the textrel_shlib_t label"
