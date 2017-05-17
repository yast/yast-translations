# All YaST Translations

run tools/update-tool.sh to update pot+po files
This is not needed in normal situation. Changes are merged automatically by Jenkins and update-tool-cron.sh.
It is required:
- After fixing a bug in the tools code.
- When new domain appears.
Note that the tool currently requires ssh access to the weblate server to create new projects or branches.

tools/yast-check-lcn-import.sh can be used to check consistency


# The YaST Translations Process

- Developer changes source code
- Developer starts pull request on GitHub for that YaST subproject
- Other developer reviews the changed code
- Pull request is merged
- Jenkins CI build is triggered
- Upon success, the .pot files are generated in Jenkins
- Resulting .pot files are automatically checked into WebLate by Jenkins
- WebLate integrates new or changed messages into the .po.xy files


## openSUSE Products (Tumbleweed, Leap)

- Community translators translate the changed messages in the .po.xy files
- Community translators check their changes in to WebLate
- Weblate pushes changes to GitHub
- .mo.xy files are generated
- yast-trans-xy packages are rebuilt
- Update repos and installation ISOs are rebuilt with those new yast-trans-xy
  packages



## SLE Products

- .pot files are checked into the translation SVN (manual step)
- Translation coordinator pulls pot files from SVN to a proprietary tool
- Professional translators translate the changed messages in the .po.xy files
- Translators check their changes into proprierary tool
- Translatoion coordinators check their changes into SVN
- .mo.xy files are generated (triggered manually (?))
- yast-trans-xy packages are rebuilt
- Update repos and installation ISOs are rebuilt with those new yast-trans-xy
  packages


## Contact

### Translation Coordination

- Stanislav Brabec <sbrabec@suse.com>
- Karl Eichwalder <ke@suse.com>

### YaST Side

- Creating .pot files in Jenkins: Christopher Hofmann <cwh@suse.com>
- Jenkins in general: Ladislav Slezak <lslezak@suse.com>

- YaST development IRC: #yast at irc.freenode.org
