# User Directory Layout

Working on the HPC, many bioinformaticians face the problem of hard `$HOME` directory space limit. Usually users have primary directory (something like `/home/research/user_name`) and an additional group-specific directory with more available space (something like `/hpc/group_name/user_name`).

Programs like RStudio and Apptainer (Singularity) quickly fill up the `$HOME` directory under the default settings with notebooks and container cache. Conda environments, R libraries and user-specific programs do the same. User-specific binaries are binaries for which you are the only user. They can be for example your personal installation of conda. Usually they are installed in `$HOME/bin` or `$HOME/.local/bin` directory. To overcome this issue I suggest to move all user-specific binaries, program data, configs, etc. to the secondary directory (usually user's subdirectory in their scientific group) and instruct the programs to use them.

This is where XDG base directory specification comes to help. It is a standard for directory layout used for user-specific files. Many programs already use XDG so that migration should not be a total headache.

# XDG Base Directory Specification
You can find more details on [this page](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html). In short:

- XDG_DATA_HOME is used for app data files. Defaults to `$HOME/.local/share`.
- XDG_CONFIG_HOME is used for app configuration files. Defaults to `$HOME/.config`.
- XDG_STATE_HOME is used for app session data, which should be stored for reuse. Defaults to `$HOME/.local/state`.
- XDG_CACHE_HOME for app cache: `$HOME/.cache`.
- XDG_RUNTIME_DIR for app runtime files with no default. Commonly used values are `/tmp` or `$TMPDIR`

All the necessary directories should be created before they are going to be used by programs. Although it is not part of the official specification, it is recommended to put user-specific binaries to `$HOME/.local/bin`.

# Step by Step Guide
## 1. Setting environment variables

First, XDG defined environment variables should be added to `~/.bash_profile`. Add the following lines to the file:

```bash
# ~/.bash_profile content


GROUP_NAME=your_group_name
export XDG_DATA_HOME=/hpc/$GROUP_NAME/$USER/.local/share
export XDG_STATE_HOME=/hpc/$GROUP_NAME/$USER/.local/state
export XDG_BIN_HOME=/hpc/$GROUP_NAME/$USER/.local/bin
export XDG_CACHE_HOME=/hpc/$GROUP_NAME/$USER/.cache
export XDG_CONFIG_HOME=/hpc/$GROUP_NAME/$USER/.config
export XDG_RUNTIME_DIR=${TMPDIR:-/tmp} # This will default to $TMPDIR if it is set or to /tmp otherwise

PATH=$PATH:$XDG_BIN_HOME
export PATH
```

The following directories have to be created:

```bash
mkdir -p /hpc/$GROUP_NAME/$USER/.local/bin
mkdir /hpc/$GROUP_NAME/$USER/.local/share
mkdir /hpc/$GROUP_NAME/$USER/.local/state
mkdir /hpc/$GROUP_NAME/$USER/.config
mkdir /hpc/$GROUP_NAME/$USER/.cache
```

## Git
Git already follows the XDG specification and no setup is needed. However, if the `.gitconfig` file is in your `$HOME` directory you need to move it to the XDG defined directory:

```bash
echo $XDG_CONFIG_HOME # check the variable is set
mkdir $XDG_CONFIG_HOME/git/
touch $XDG_CONFIG_HOME/git/config # this has to be a file
cat .gitconfig > $XDG_CONFIG_HOME/git/config # copy the contents
rm .gitconfig
git config --list # check that git uses the config file from new location
```

## R
[The R language seems to support](https://search.r-project.org/R/refmans/tools/html/userdir.html) the XDG base directory specification. I didn't test this myself, but for compatibility I would set the following R-specific environment variables:

```bash
# ~/.bash_profile content

export R_USER_DATA_DIR=$XDG_DATA_HOME
export R_USER_CONFIG_DIR=$XDG_CONFIG_HOME
export R_USER_CACHE_DIR=$XDG_CACHE_HOME
```

Do not forget to install R to `/hpc/$GROUP_NAME/$USER/.local/bin`. You don't need to do that if your R installation comes from conda/mamba/pixi or other package manager.

```bash
export R_VERSION=4.4.1
curl -O https://cran.rstudio.com/src/base/R-4/R-${R_VERSION}.tar.gz
tar -xzvf R-${R_VERSION}.tar.gz
cd R-${R_VERSION}
./configure \
  --prefix=/${XDG_BIN_HOME}/R/${R_VERSION} \
  --enable-R-shlib \
  --enable-memory-profiling
make && make install
```

## RStudio
[RStudio already follows](https://docs.posit.co/ide/desktop-pro/2022.02.3+492.pro3/settings.html) the XDG base directory specification and no additional actions are needed.

## Conda and Mamba

I recommend installing conda and mamba using [miniforge installer](https://github.com/conda-forge/miniforge). It is interactive and you can specify installation path to `/hpc/$GROUP_NAME/$USER/.local/bin`.

Run the following command to create `.condarc` file and use mamba with all conda calls:

```bash
conda config --set solver libmamba
```
This file seems to be created in the `$HOME` directory by default. Simply move it to the `$XDG_CONFIG_HOME` as conda is configured to look at `$XDG_CONFIG_HOME/conda/.condarc`.

Unfortunately, conda also creates a `~/.conda` directory with `environments.txt` file, which is currently hardcoded in conda and [it is not possible to move](https://github.com/conda/conda/issues/8804). You can leave it there or use [a patched version of conda](https://github.com/libranet/conda-xdgpatch) (not recommended).

## Jupyter, IPython and other python-specific

Jupyter is moving towards XDG base directory specification. For compliance I would set Jupyter-specific environmental variables in `~/.bash_profile`:

```bash
export JUPYTER_CONFIG_DIR=${XDG_CONFIG_HOME}/jupyter
export JUPYTER_DATA_DIR=${XDG_DATA_HOME}/jupyter
export JUPYTER_RUNTIME_DIR=${XDG_RUNTIME_DIR}/$USER-jupyter
```

IPython used to support XDG based directory specification, but then _returned to the stone age_. If Ipython creates anything in `~/.ipython` you need to manually move these files to XDG compliant directory. 

```bash
export IPYTHONDIR=${XDG_CONFIG_HOME}/ipython
```

Matplotlib is a heavy library with many configuration options. By default is respects XDG specification, but if `MPLCONFIGDIR` is set it will put both configuration and cache files in that directory. Do not set this environment variable.

Pip respects `XDG_CACHE_HOME`. You don't need to do anything.

## Singularity/Apptainer

To make singularity/apptainer compliant with XDG you need to add these lines to `~/.bash_profile`:

```bash
export SINGULARITY_CONFIGDIR=${XDG_CONFIG_HOME}/singularity
export SINGULARITY_CACHEDIR=${XDG_CACHE_HOME}/singularity
export APPTAINER_CONFIGDIR=${XDG_CONFIG_HOME}/apptainer
export APPTAINER_CACHEDIR=${XDG_CACHE_HOME}/apptainer
```

## Other

VSCode has two options to run in XDG-compliant way:

```bash
# 1 option
export VSCODE_PORTABLE=${XDG_DATA_HOME}/vscode # this is not documented and might break

# 2 option
code --extensions-dir ${XDG_DATA_HOME}/vscode
```

[This wiki page](https://wiki.archlinux.org/title/XDG_Base_Directory) has an extensive list of other software packages and how to run them in XDG-compliant way.
