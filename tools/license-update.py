#!/usr/bin/python3
#
# Update licenses on YaST projects
#
# Prerequisities:
# yast-translations/tools as working directory
# YaST checkout in ~/yast-checkout
# weblate-ssh command with access to the Weblate server in PATH
# OSC account credentials
# internal SUSE account credentials (optional)
#
import os
import glob
import pathlib
import subprocess
import re
import shutil

sle_repo = 'SUSE:SLE-15-SP2:GA'
opensuse_repo = 'openSUSE:Factory'
weblate_ssh = shutil.which('weblate-ssh')

def weblate_django_shell(command_string):
  print("going to execute:\n------\n" + command_string + "------\n")
  subprocess.run(['weblate-ssh', 'su -l -s /usr/bin/python3 wwwrun /usr/share/weblate/manage.py shell'],
    input=command_string.encode())

pots = glob.glob("../po/*/*.pot")

for pot_file in pots:
  pot = os.path.basename(pot_file)
  wlprj = "yast-" + pot.rsplit(".pot")[0]
  print(wlprj + ' weblate project')
  prjpots = glob.glob(os.path.expanduser("~/yast-checkout/*/") + pot)
  prjlicenses = []
  for ff in prjpots:
    prjdir = os.path.dirname(ff)
    prj = os.path.basename(prjdir)
    if os.path.exists(prjdir + "/RPMNAME"):
      prjpkg = pathlib.Path(prjdir + "/RPMNAME").read_text().strip()
    else:
      prjpkg = prj
    print('      ' + prj + ' repo: ' + prjpkg + ' package')
    try:
      spec = subprocess.check_output(['osc', 'cat', opensuse_repo, prjpkg, prjpkg + '.spec']).decode('utf-8')
    except:
# If you have no access to SLE OBS (IBS), feel free to comment out this line.
      try:
        spec = subprocess.check_output(['osc', '-A', 'https://api.suse.de/', 'cat', sle_repo, prjpkg, prjpkg + '.spec']).decode('utf-8')
      except:
        print('  FAILURE! Package named ' + prjpkg + ' was not found!')
        continue
    spec_license_line = re.findall('^License:.*$', spec, re.MULTILINE)[0]
    spec_license = re.sub('License:', '', spec_license_line).strip()
    print('        "' + spec_license + '" partial license')
    if not spec_license in prjlicenses:
      prjlicenses.append(spec_license)
  if len(prjlicenses) == 0:
    continue
  if len(prjlicenses) == 1:
    final_license = prjlicenses[0]
  else:
    final_license = '(' + ') AND ('.join(prjlicenses) + ')'
  print('  "' + final_license + '" final license')
  weblate_django_shell(
'''from weblate.trans.models.project import Project
from weblate.trans.models.component import Component
project = Project.objects.get(name="''' + wlprj + '''")
component = Component.objects.get(project=project, name="master")
component.license = "''' + final_license + '''"
component.save()
''')
