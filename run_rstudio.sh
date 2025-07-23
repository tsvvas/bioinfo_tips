#!/bin/bash
#SBATCH --job-name=rstudio
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --mincpus=4
#SBATCH --mem=64G
#SBATCH --signal=USR2

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

R_LIBS_USER="$XDG_DATA_HOME/R/rocker-rstudio/4.4.2"
[[ -d "$R_LIBS_USER" ]] || mkdir -p "$R_LIBS_USER"

# Adapted from here: https://rocker-project.org/use/singularity.html
workdir=$(mktemp -d)
cat > ${workdir}/rsession.sh <<"END"
#!/bin/sh
export R_LIBS_USER="${XDG_DATA_HOME}/R/rocker-rstudio/"
## custom Rprofile & Renviron (default is $HOME/.Rprofile and $HOME/.Renviron)
# export R_PROFILE_USER=/path/to/Rprofile
# export R_ENVIRON_USER=/path/to/Renviron
exec /usr/lib/rstudio-server/bin/rsession "${@}"
END

chmod +x ${workdir}/rsession.sh

cat > ${workdir}/rsession.conf << END
session-default-working-dir=$PROJECTDIR
session-default-new-project-dir=$PROJECTDIR/projects
END

export APPTAINERENV_R_LIBS_USER=$R_LIBS_USER
export APPTAINERENV_XDG_DATA_HOME=$XDG_DATA_HOME
export APPTAINERENV_XDG_CONFIG_HOME=$XDG_CONFIG_HOME
export APPTAINERENV_XDG_STATE_HOME=$XDG_STATE_HOME
export APPTAINERENV_XDG_CACHE_HOME=$XDG_CACHE_HOME

singularity run \
    --cleanenv \
    --app rserver \
    --bind "$PROJECTDIR",/scratch \
    --bind "$XDG_CACHE_HOME"/rstudio-server:/var/lib/rstudio-server \
    --bind "$XDG_STATE_HOME"/rstudio-server:/var/run/rstudio-server \
    --bind "$TMPDIR":/tmp \
    --bind "$XDG_CACHE_HOME"/.jovyan:/home/jovyan \
    --bind ${workdir}/rsession.sh:/etc/rstudio/rsession.sh \
    --bind ${workdir}/rsession.conf:/etc/rstudio/rsession.conf \
    "$CONTAINER_PATH" \
    --www-port 8989 \
    --www-address 0.0.0.0 \
    --server-user $USER \
    --rsession-path=/etc/rstudio/rsession.sh 
