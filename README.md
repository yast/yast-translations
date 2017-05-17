# All YaST Translations

run tools/update-tool.sh to update po files

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
- .mo.xy files are generated
- yast-trans-xy packages are rebuilt
- Update repos and installation ISOs are rebuilt with those new yast-trans-xy
  packages



## SLE Products

- .pot files are checked into the translation SVN (manual step)
- Professional translators translate the changed messages in the .po.xy files
- Translators check their changes in to SVN
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
