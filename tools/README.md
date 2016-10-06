# update-tool-cron.sh
## automatically create, update and submit POT files

### Requirements:
- yast2-devtools.rpm

  after installation, add /usr/share/YaST2/data/devtools/bin/ to your $PATH

- `y2m` from `https://github.com/yast/yast-meta`

  put it in your in $PATH


- a version of `rubygem-gettext` that fits your ruby version

### Preparation:

- Get the script from github: `https://github.com/cwh42/yast-translations/blob/master/tools/update-tool-cron.sh`
   and put it to your $PATH

- make sure you have a github account with appropriate permissions to clone
  all yast module repositories and have write access to the yast-translations repository

- create a working directory and call `y2m clone ALL` to git-clone all yast
  modules into that directory

### Usage:
`update-tool-cron.sh` needs to be run in a directory containing a checkout of all
yast modules, like it is created by `y2m clone ALL`

### How it works
It
- iterates through each of the cloned yast modules in the working directory, except 'translations'
- does a `y2m pull` to fetch the latest commits from upstream
- calls y2makepot to create POT files for all the text domains used by the
  module
- does some normalization of the POT files to make them comparable
- finds out whether POT files changed
  - if they changed, it updates them in the translations-repo and merges them
    into the already existing PO-files
  - finally a `git commit` is done in the translations-repo for each updated text-
    domain

It does not do a `git push` – this should be done afterwards depending on the
exit status of the script.

### Example script used in our Jenkins setup:
```shell
if [ ! -d $HOME/yast-all ]; then
  mkdir $HOME/yast-all
  cd $HOME/yast-all
  y2m clone ALL
else
  cd $HOME/yast-all
fi

export PATH=$PATH:/usr/share/YaST2/data/devtools/bin
translations/tools/update-tool-cron.sh && git push
```
