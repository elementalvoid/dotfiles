[[ $- = *i* ]] || return

complete -C terraform terraform

function tfgen() {
  local tfdir=$(basename $(pwd))
  echo "${tfdir}: Installing Terraform..."
  asdf install terraform
  echo "${tfdir}: Formatting..."
  terraform fmt .

  echo "${tfdir}: Installing Terraform Docs..."
  asdf install terraform-docs
  echo "${tfdir}: Generating docs..."
  terraform-docs . > README.md
}

function tfgen-all() {
  for i in *; do
    (cd $i; tfgen)
  done
}

# Print usage for update-terraform-lockfiles.
function _utl_usage() {
  cat <<'EOF'
update-terraform-lockfiles — (re)generate Terraform provider lock files

USAGE:
  update-terraform-lockfiles [options] [path ...]

OPTIONS:
  -p, --provider SRC   Re-lock ONLY this provider, leaving every other entry
                       pinned. Repeatable. Accepts a short name like
                       "hashicorp/aws" (assumes registry.terraform.io) or a
                       full source like "example.jfrog.io/ns/myprovider".
      --platform PLAT  Platform to lock for. Repeatable. First use REPLACES the
                       default set (linux_amd64, darwin_amd64, darwin_arm64).
  -h, --help           Show this help and exit.

PATHS:
  Directories/files searched for providers.tf (via fd). Defaults to ".".

MODES:
  Full regen (no -p):  removes .terraform and .terraform.lock.hcl, then locks
                       every provider at the newest version allowed by config.
  Targeted  (-p ...):  keeps the existing lock, surgically removes only the
                       named provider blocks, then re-locks just those — so a
                       single provider can be bumped without disturbing others.
                       The lock is backed up and restored on any failure.

NOTES:
  * Run where `terraform` matches the repo's .terraform-version (asdf/mise
    shim); the CLI version affects lock formatting. A mismatch is warned about.
EOF
}

# Surgically remove a single provider block from a lock file, with verification.
# Args: <lockfile> <full-provider-source>. Returns non-zero on any anomaly and
# leaves the lock file untouched.
function _utl_strip_provider_block() {
  emulate -L zsh
  local lockfile=$1 src=$2 tmp before after blocks_before blocks_after

  before=$(grep -c "^provider \"${src}\" {" "$lockfile" 2>/dev/null); [[ -n $before ]] || before=0
  if (( before == 0 )); then
    print -u2 "  ! '${src}' not present in lock (will be added fresh)"
    return 0
  fi
  if (( before > 1 )); then
    print -u2 "  ✗ '${src}' appears ${before}× in ${lockfile} — refusing to edit"
    return 1
  fi

  tmp=$(mktemp) || { print -u2 "  ✗ mktemp failed"; return 1; }

  # -0777 slurps the whole file; /sm so ^/$ are line-anchored and . spans lines.
  # The opening line starts at column 0 and the block ends with a column-0 '}'.
  perl -0777 -pe 'BEGIN{$s=shift @ARGV} s{^provider "\Q$s\E" \{.*?^\}\n\n?}{}sm' \
    "$src" "$lockfile" > "$tmp"
  if (( $? != 0 )); then
    print -u2 "  ✗ perl failed editing ${lockfile}"; rm -f "$tmp"; return 1
  fi

  after=$(grep -c "^provider \"${src}\" {" "$tmp" 2>/dev/null); [[ -n $after ]] || after=0
  if (( after != 0 )); then
    print -u2 "  ✗ removal check failed for '${src}' (${after} still present)"; rm -f "$tmp"; return 1
  fi
  if [[ ! -s $tmp ]]; then
    print -u2 "  ✗ resulting lock would be empty — aborting"; rm -f "$tmp"; return 1
  fi

  # Guard: exactly one provider block should have disappeared, nothing else.
  blocks_before=$(grep -c '^provider "' "$lockfile")
  blocks_after=$(grep -c '^provider "' "$tmp")
  if (( blocks_before - blocks_after != 1 )); then
    print -u2 "  ✗ expected to drop 1 block, dropped $(( blocks_before - blocks_after )) — aborting"
    rm -f "$tmp"; return 1
  fi

  mv "$tmp" "$lockfile"
}

function update-terraform-lockfiles() {
  emulate -L zsh
  setopt local_options

  local -a providers platforms paths sources platform_flags files
  platforms=(linux_amd64 darwin_amd64 darwin_arm64)
  local platforms_overridden=0 p file dir rc=0

  while (( $# )); do
    case $1 in
      -h|--help) _utl_usage; return 0 ;;
      -p|--provider)
        [[ -n $2 ]] || { print -u2 "error: $1 requires an argument"; return 2; }
        providers+=("$2"); shift 2 ;;
      --platform)
        [[ -n $2 ]] || { print -u2 "error: --platform requires an argument"; return 2; }
        (( platforms_overridden )) || { platforms=(); platforms_overridden=1; }
        platforms+=("$2"); shift 2 ;;
      --) shift; paths+=("$@"); break ;;
      -*) print -u2 "error: unknown option: $1"; _utl_usage; return 2 ;;
      *) paths+=("$1"); shift ;;
    esac
  done
  (( ${#paths} )) || paths=(.)

  for p in $platforms; do platform_flags+=(--platform "$p"); done

  # Normalize provider sources: prepend the public registry host unless the
  # first segment already looks like a hostname (contains a dot).
  for p in $providers; do
    if [[ ${p%%/*} == *.* ]]; then sources+=("$p"); else sources+=("registry.terraform.io/$p"); fi
  done

  files=("${(@f)$(fd providers.tf $paths 2>/dev/null)}")
  if (( ! ${#files} )) || [[ -z ${files[1]} ]]; then
    print -u2 "no providers.tf found under: $paths"; return 1
  fi

  for file in $files; do
    dir=${file:h}
    print "== $dir =="
    (
      cd "$dir" || exit 1

      # Warn (don't fail) if the active terraform differs from the repo pin.
      if [[ -f .terraform-version ]]; then
        local pinned cur
        pinned=$(<.terraform-version)
        cur=$(terraform version 2>/dev/null | head -1 | sed -E 's/^Terraform v//')
        [[ $pinned == $cur ]] || print -u2 "  ! terraform ${cur:-?} active but .terraform-version pins ${pinned} (lock format may drift)"
      fi

      if (( ${#sources} == 0 )); then
        # ---- full regen ----
        rm -rf .terraform .terraform.lock.hcl
        terraform get >/dev/null || { print -u2 "  ✗ terraform get failed"; exit 1; }
        terraform providers lock $platform_flags || exit 1
      else
        # ---- targeted: bump only named providers ----
        local had_lock=0 src
        if [[ -f .terraform.lock.hcl ]]; then
          had_lock=1
          cp .terraform.lock.hcl .terraform.lock.hcl.utlbak || exit 1
          for src in $sources; do
            if ! _utl_strip_provider_block .terraform.lock.hcl "$src"; then
              print -u2 "  ✗ aborting; restoring original lock"
              mv .terraform.lock.hcl.utlbak .terraform.lock.hcl
              exit 1
            fi
          done
        else
          print -u2 "  ! no .terraform.lock.hcl present; locking only: $sources"
        fi

        terraform get >/dev/null || {
          print -u2 "  ✗ terraform get failed"
          (( had_lock )) && mv .terraform.lock.hcl.utlbak .terraform.lock.hcl
          exit 1
        }

        if ! terraform providers lock $platform_flags $sources; then
          print -u2 "  ✗ terraform providers lock failed; restoring original lock"
          (( had_lock )) && mv .terraform.lock.hcl.utlbak .terraform.lock.hcl
          exit 1
        fi

        for src in $sources; do
          if ! grep -q "^provider \"${src}\" {" .terraform.lock.hcl; then
            print -u2 "  ✗ '${src}' missing from lock after locking; restoring"
            (( had_lock )) && mv .terraform.lock.hcl.utlbak .terraform.lock.hcl
            exit 1
          fi
        done
        (( had_lock )) && rm -f .terraform.lock.hcl.utlbak
      fi
      print "  ✓ ${dir}"
    ) || rc=1
  done
  return $rc
}

# vim: set ft=sh ts=2 sw=2 tw=0 :
