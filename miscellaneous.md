# Miscellaneous

## SLURM
Run bash in SLURM:
```
srun --nodes=1 --mincpus=2 --mem=64G  --time=6:00:00 --gres=tmpspace:40G --pty bash
srun --nodes=1 --mincpus=2 --mem=32G  --time=4:00:00 --gres=tmpspace:40G --pty bash
```
Check details of a job
```
scontrol show jobid -dd 1234567
```
Check resource usage of a finished job
```
seff 1234567
```
Change `sacct` format to get more info about running jobs
```
export SACCT_FORMAT="JobID%20,JobName,User,Partition,NodeList,Elapsed,CPUTime,MaxRSS,State,AllocTRES%32"
```

## Singularity
Check the definition file of a singularity container.
```
singularity exec singularity.sif cat /.singularity.d/Singularity
```


## Download from zenodo
This command will return a json with links assigned to the record. You can parse it and display in human readable way using `jq` command line utility.
```
curl https://zenodo.org/api/records/<record_id>
```
In this example we get the metadata of ISS dataset in zenodo and extract the link to the adata object.
```
curl -s https://zenodo.org/api/records/6807534 | jq '.files | .[0].links.self'
```
This downloads the data
```
curl -s https://zenodo.org/api/records/6807534 | jq '.files | .[0].links.self' | xargs curl -O
```
Continue download if the connection was broken.
```
curl -s https://zenodo.org/api/records/6962901 | jq '.files | .[5] | .links.self' | xargs -I url curl -O -C - url
```

## Download data from NCBI
Downloads all files from the links and keeps the names
```
wget --content-disposition -i data_links.txt
```

## Terminal 

Prettify PATH string
```
echo $PATH | sed --expression="s/:/\n/g"
```
Extract tar gz archive
```
tar -xvzf community_images.tar.gz
tar -xvzf community_images.tar.gz -C some_custom_folder_name
```
See the content of tar gz without extracting it
```
tar -tf filename.tar.gz
```
Extract all tar.gz files in the folder
```
cat *.tar.gz | tar zxvf - -i
```
Untar uncompressed tarball
```
tar -xf filename.tar
```
Diff for two json files:
```
diff <(jq --sort-keys . A.json) <(jq --sort-keys . B.json)
```

## SSH
Create a tunnel in master mode for [easy control over connection](https://stackoverflow.com/questions/67494107/how-do-i-properly-open-a-ssh-tunnel-in-the-background):
```
ssh -M -S ~/vscode-tunnel -o "ExitOnForwardFailure yes" -fN hpc -L 9090:n0122:9090
ssh -S ~/vscode-tunnel -O exit hpc
```

## Git
Pretty-print json before comparing it [to the committed version in git](https://gist.github.com/Ricket/78bcd681db86bcbb134558428c4c6cb4):
echo "*.json diff=json" >> ~/.gitattributes
git config --global core.attributesfile ~/.gitattributes
git config --global diff.json.textconv "jq '.' \$1"

## Conda config
Always use libmamba with conda calls.
```
conda config --set solver libmamba
```

## AWK
Remove lines with missing values in 1 or 2 columm:
```
awk -F"," ' $1 && $2 { print $0 }' file.csv
```
Read first and last column
```
awk -F',' '{ print $1 "," $NF }' file.csv
```
Read first two columns and replace header
```
{ printf 'Barcode,Annotation\n'; tail -n +2 file.csv | awk -F',' '{ print $1 "," $NF }'; }
```
