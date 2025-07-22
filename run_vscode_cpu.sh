#!/bin/bash
#SBATCH --job-name=code_cpu
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --mincpus=4
#SBATCH --mem=64G

export PYTHONPATH=$PYTHONPATH:$SLURM_SUBMIT_DIR
export NUMBA_CACHE_DIR=$TMPDIR
export MPLCONFIGDIR=$XDG_CACHE_HOME/.matplotlib
export RUFF_CACHE_DIR=$XDG_CACHE_HOME/.ruff

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

singularity run \
    --app codeserver \
    --bind "$PROJECTDIR",/scratch \
    --bind "$XDG_CACHE_HOME"/.jovyan:/home/jovyan \
    "$CONTAINER_PATH" \
    --bind-addr 0.0.0.0:9090 \
    --auth none \
    --disable-telemetry \
    --user-data-dir "$XDG_DATA_HOME"/code-server


