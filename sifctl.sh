#!/usr/bin/env bash
# sifctl - Local SIF Container Registry Manager
#
# This script implements a simple filesystem-based container registry for
# Apptainer/Singularity SIF images. Images are stored by their SHA256 digest
# under:
#
#   $CONTAINERDIR/digests/
#       sha256-<digest>.sif
#
# Tags are represented as symbolic links under:
#
#   $CONTAINERDIR/tags/<name>/<tag> -> ../../digests/sha256-<digest>.sif
#
# Tag aliases (e.g., "latest", "cpu-latest") are symlinks to other tags:
#
#   $CONTAINERDIR/tags/<name>/<alias> -> <tag>
#
# This provides a lightweight, reproducible container-versioning mechanism
# consistent with OCI/Docker-style naming (name:tag), without needing a
# registry server.
#
# The following commands are supported:
#
#   push       Add a SIF image and tag it
#   pull       Retrieve an image by name:tag into a local file
#   tag-alias  Create a tag alias pointing to another tag
#   resolve    Resolve a tag to the underlying SIF file path
#   list       List available images or tags for a given image
#
# Required environment variable:
#
#   CONTAINERDIR   Path to the root of the local registry.
#                  Must already exist, e.g.:
#                      export CONTAINERDIR="$HOME/sif-registry"
#
# The script will exit if CONTAINERDIR is not set.
#
# Example:
#
#   sifctl push rnaseq_cpu_0.1.2.sif rnaseq-pipeline:cpu-v0.1.2
#   sifctl pull rnaseq-pipeline:cpu-v0.1.2 rnaseq_cpu.sif
#   sifctl tag-alias rnaseq-pipeline cpu-v0.1.2 cpu-latest
#   sifctl resolve rnaseq-pipeline:cpu-latest
#   sifctl list rnaseq-pipeline
#
# This tool is self-contained and requires only bash, coreutils, and symlinks.

if [[ -z "${CONTAINERDIR}" ]]; then
    echo "Error: CONTAINERDIR is not set." >&2
    echo "Please set CONTAINERDIR to your local registry root" >&2
    exit 1
fi

CONTAINERDIR="${CONTAINERDIR}/sif-store"

usage() {
    cat <<EOF
sifctl - manage a local SIF image registry

Usage:
  sifctl push IMAGE.sif NAME[:TAG]
      Add a SIF image to the registry and create/update a tag.

  sifctl pull NAME[:TAG] [OUTPUT.sif]
      Copy the resolved SIF image to a file.
      If OUTPUT is omitted, it writes ./<name>_<tag>.sif.

  sifctl tag-alias NAME FROM_TAG ALIAS_TAG
      Create an alias tag (a symlink to another tag).

  sifctl resolve NAME[:TAG]
      Resolve a tag to an absolute filesystem path of the SIF file.

  sifctl list [NAME]
      List all image names, or all tags under a specific name.

  sifctl help
      Show this help message.

Environment:
  CONTAINERDIR
      Root of the local registry

Registry layout:
  \$CONTAINERDIR/
    digests/
      sha256-<digest>.sif
    tags/
      <name>/
        <tag>         -> ../../digests/sha256-<digest>.sif
        <alias-tag>   -> <tag>

Examples:
  sifctl push rnaseq-1.4.2.sif rnaseq-pipeline:cpu-v0.1.2
  sifctl pull rnaseq-pipeline:cpu-v0.1.2 rnaseq_cpu.sif
  sifctl tag-alias rnaseq-pipeline cpu-v0.1.2 cpu-latest
  sifctl resolve rnaseq-pipeline:cpu-latest
  sifctl list rnaseq-pipeline
EOF
}

log() {
    printf '%s\n' "$*" >&2
}

die() {
    log "Error: $*"
    exit 1
}

sif_digest() {
    local image_file="$1"
    sha256sum "$image_file" | awk '{print $1}'
}

cmd_push() {
    local image_file="$1"
    local ref="$2"

    [[ -f "$image_file" ]] || die "image file not found: $image_file"

    local name tag
    if [[ "$ref" == *:* ]]; then
        name="${ref%%:*}"
        tag="${ref##*:}"
    else
        name="$ref"
        tag="latest"
    fi

    [[ -n "$name" && -n "$tag" ]] || die "invalid reference '$ref' (expected NAME[:TAG])"

    mkdir -p "$CONTAINERDIR/digests" "$CONTAINERDIR/tags/$name"

    local digest digest_file
    digest="$(sif_digest "$image_file")"
    digest_file="$CONTAINERDIR/digests/sha256-$digest.sif"

    if [[ ! -f "$digest_file" ]]; then
        cp "$image_file" "$digest_file"
        log "Stored new digest: $digest_file"
    else
        log "Digest already exists: $digest_file"
    fi

    (
        cd "$CONTAINERDIR/tags/$name" || die "Cannot cd in $CONTAINERDIR/tags/$name"
        ln -sfn "../../digests/sha256-$digest.sif" "$tag"
    )

    log "Tagged: $name:$tag -> sha256-$digest"
}

cmd_pull() {
    local ref="$1"
    local out="${2:-}"
    local src
    src="$(cmd_resolve "$ref")" || die "failed to resolve $ref"

    if [[ -n "$out" ]]; then
        dest="$out"
    else
        local name tag
        if [[ "$ref" == *:* ]]; then
            name="${ref%%:*}"
            tag="${ref##*:}"
        else
            name="$ref"
            tag="latest"
        fi
        dest="./${name}_${tag}.sif"
    fi

    cp "$src" "$dest" || die "copy failed"

    log "Pulled $ref → $dest"
}


cmd_tag_alias() {
    local name="$1"
    local from_tag="$2"
    local alias_tag="$3"

    local tag_dir="$CONTAINERDIR/tags/$name"
    [[ -d "$tag_dir" ]] || die "no such image name directory: $tag_dir"

    (
        cd "$tag_dir" || die "Cannot cd in $tag_dir"
        [[ -e "$from_tag" ]] || die "source tag '$from_tag' does not exist under '$name'"
        ln -sfn "$from_tag" "$alias_tag"
    )

    log "Alias created: $name:$alias_tag -> $name:$from_tag"
}

cmd_resolve() {
    local ref="$1"

    local name tag
    if [[ "$ref" == *:* ]]; then
        name="${ref%%:*}"
        tag="${ref##*:}"
    else
        name="$ref"
        tag="latest"
    fi

    local path="$CONTAINERDIR/tags/$name/$tag"
    [[ -e "$path" ]] || die "tag not found: $ref"

    readlink -f "$path"
}

cmd_list() {
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        local dir="$CONTAINERDIR/tags"
        [[ -d "$dir" ]] || { log "No images found (no tags directory yet)"; return 0; }

        log "Images in $CONTAINERDIR:"
        find "$dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
    else
        local dir="$CONTAINERDIR/tags/$name"
        [[ -d "$dir" ]] || die "no such image name: $name"

        log "Tags for $name:"
        (
            cd "$dir" || die "Cannot cd in $dir"
            for t in *; do
                [[ -e "$t" ]] || continue
                target="$(readlink "$t" || true)"
                printf '%-20s -> %s\n' "$t" "$target"
            done | sort
        )
    fi
}

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        push)
            [[ $# -eq 2 ]] || { usage; die "push requires IMAGE.sif and NAME[:TAG]"; }
            cmd_push "$@"
            ;;
        pull)
            [[ $# -ge 1 && $# -le 2 ]] || { usage; die "pull requires NAME[:TAG] [OUTPUT]"; }
            cmd_pull "$@"
            ;;
        tag-alias)
            [[ $# -eq 3 ]] || { usage; die "tag-alias requires NAME FROM_TAG ALIAS_TAG"; }
            cmd_tag_alias "$@"
            ;;
        resolve)
            [[ $# -eq 1 ]] || { usage; die "resolve requires NAME[:TAG]"; }
            cmd_resolve "$@"
            ;;
        list)
            [[ $# -le 1 ]] || { usage; die "list takes at most one argument [NAME]"; }
            cmd_list "${1:-}"
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            usage
            die "unknown command: $cmd"
            ;;
    esac
}

main "$@"
