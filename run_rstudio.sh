#!/bin/bash
#SBATCH --job-name=rstudio
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --mincpus=4
#SBATCH --mem=64G

USE_PROJECT_DIR=0
CONTAINER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t)
            USE_PROJECT_DIR=1
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            CONTAINER="$1"
            shift
            ;;
    esac
done

CONTAINER=${CONTAINER:-spatial}

if [ -n "$SLURM_GPUS" ]; then
    echo "GPUs allocated: $SLURM_GPUS"
else
    echo "GPUs allocated: None"
fi

if [ "$USE_PROJECT_DIR" -eq 1 ]; then
    CONTAINER_PATH="$PROJECTDIR/containers/$CONTAINER.sif"
else
    CONTAINER_PATH="$CONTAINERDIR/$CONTAINER.sif"
fi

if [ ! -f "$CONTAINER_PATH" ]; then
    echo "Error: Container $CONTAINER_PATH not found!"
    exit 1
fi

echo "Job started at: $(date)"
echo "Running container: $CONTAINER_PATH"
echo "Node: $SLURMD_NODENAME"
echo "CPUs allocated: $SLURM_CPUS_ON_NODE"

[[ -d "$XDG_CACHE_HOME"/rstudio-server ]] || mkdir -p "$XDG_CACHE_HOME"/rstudio-server
[[ -d "$XDG_STATE_HOME"/rstudio-server ]] || mkdir -p "$XDG_STATE_HOME"/rstudio-server
[[ -d "$XDG_CACHE_HOME"/.jovyan ]] || mkdir -p "$XDG_CACHE_HOME"/.jovyan

RLIBCUSTOM="$XDG_CACHE_HOME/R/%p-library/%v"

singularity run \
    --app rserver \
    --bind "$PROJECTDIR",/scratch \
    --bind "$XDG_CACHE_HOME"/rstudio-server:/var/lib/rstudio-server \
    --bind "$XDG_STATE_HOME"/rstudio-server:/var/run/rstudio-server \
    --bind "$TMPDIR":/tmp \
    --bind "$XDG_CACHE_HOME"/.jovyan:/home/jovyan \
    --env R_LIBS_USER=$RLIBCUSTOM \
    "$CONTAINER_PATH" \
    --www-port 8989 \
    --www-address 0.0.0.0 \
    --server-user $USER
