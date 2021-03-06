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
- WebLate integrates new or changed messages into the .LL.po files


## openSUSE Products (Tumbleweed, Leap)

- Community translators translate the changed messages in the .LL.po files
- Community translators check their changes in to WebLate
- Weblate pushes changes to GitHub
- .LL.mo files are generated
- yast-trans-LL packages are rebuilt
- Update repos and installation ISOs are rebuilt with those new yast-trans-LL
  packages



## SLE Products

- .pot files are checked into the translation SVN (manual step)
- Translation coordinator (Globalization Services) pulls .pot files from SVN to a proprietary tool
- Vendor translators translate the changed messages in the .LL.po files
- [Vendor translators check their changes into proprierary tool]
- Vendor translators check their changes into SVN
- yast-trans-LL packages are rebuilt (.LL.mo files are compiled in the OBS)
- Update repos and installation ISOs are rebuilt with those new yast-trans-LL
  packages


## Contact

### Translation Coordination

- Stanislav Brabec <sbrabec@suse.com>
- Karl Eichwalder <ke@suse.com>

### YaST Side

- Creating .pot files in Jenkins: Christopher Hofmann <cwh@suse.com>
- Jenkins in general: Ladislav Slezak <lslezak@suse.com>

- YaST development IRC: #yast at irc.libera.chat, or use the web frontend
  for the [#yast](https://web.libera.chat/#yast) IRC channel.
