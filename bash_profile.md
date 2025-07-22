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
alias .="cd .."

# Quick access to project directory
alias gtwd="cd $PROJECTDIR"

# Delete logs
alias logdel="rm *.out"

# Count pending jobs per user
alias slurm-pd="squeue |  awk ' { if (\$5 == \"PD\") ids[\$4]++ } END { PROCINFO[\"sorted_in\"] = \"@val_num_desc\"; for (user in ids) print user, \"has\", ids[user], \"pending jobs\" } '"
```

## Utilities
```
sjob () {
    sbatch $XDG_BIN_HOME/run_vscode_cpu.sh  "$@"
}
```
