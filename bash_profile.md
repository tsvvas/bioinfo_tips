# Helpful bash profile configurations

## Custom environment variables
For more information see [this page](custom_dir_layout).
```
export PROJECTDIR="/path/to/project/directory"
export CONTAINERDIR="/path/to/container/directory"
export XDG_DATA_HOME="$PROJECTDIR/.local/share"
export XDG_CACHE_HOME="$PROJECTDIR/.cache"
export XDG_CONFIG_HOME="$PROJECTDIR/.config"
export XDG_STATE_HOME="$PROJECTDIR/.local/state"
export XDG_BIN_HOME="$PROJECTDIR/.local/bin"
```

## Aliases
```
# Quick access to project directory
alias gtwd="cd $PROJECTDIR"

# Delete logs
alias logdel="rm *.out"

# Count pending jobs per user
alias slurm-pd="squeue |  awk ' { if (\$5 == \"PD\") ids[\$4]++ } END { PROCINFO[\"sorted_in\"] = \"@val_num_desc\"; for (user in ids) print user, \"has\", ids[user], \"pending jobs\" } '"
```

## Utilities
```
# CPU-only version
sjob () {
    sbatch $XDG_BIN_HOME/run_vscode_cpu.sh  "$@"
}
# CPU/GPU version
sjob() {
  local script="run_vscode_cpu.sh"
  local passthru=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -g|--gpu) script="run_vscode_gpu.sh"; shift ;;
      -c|--cpu) script="run_vscode_cpu.sh"; shift ;;
      -h|--help)
        echo "Usage: sjob [-g|--gpu] [-c|--cpu] [script-args...]"
        echo "  -g/--gpu   use GPU Slurm script"
        echo "  -c/--cpu   use CPU Slurm script (default)"
        echo "Any remaining args are passed to the script (e.g., -t, container name)."
        return 0
        ;;
      *) passthru+=("$1"); shift ;;
    esac
  done

  sbatch "$XDG_BIN_HOME/$script" "${passthru[@]}"
}
```
