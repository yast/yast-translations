#!/bin/bash

# This script generates initial projects import script. It was used only once
# and it could be called never more. Once regular projects maintenance will be
# implemented, it could be deleted. This is just a source of needed code.

BRANCH=master

set -o errexit

# generate yast_textdomain
function generate() {
	local PROJECT

	# Ugly hack! We want openSUSE for master.
	case "$1/$BRANCH" in
	control/master )
		PROJECT=skelcd-control-openSUSE
		;;
	* )
		PROJECT=$(sed -n "s/^$1 //p" <$WORKDIR/po/DOMAIN_MAP)
		;;
	esac
	echo "weblate_create_project $1 $PROJECT" >&3
	echo "weblate_create_component $1 $PROJECT $BRANCH" >&3
}

if test -f "weblate-create-projects-onetime.sh" ; then
	cd ..
fi
if ! test -f "tools/weblate-create-projects-onetime.sh" ; then
	echo "Please call this script from yast-translations top directory."
	exit 1
fi
WORKDIR=$PWD

. tools/weblate-functions.inc

exec 3>tools/weblate-create-projects-onetime-run.sh
cat >&3 <<EOF
#!/bin/bash

echo "This script was already executed. If cannot be started any more." >&2
exit 1

if test -f "weblate-create-projects-onetime-run.sh" ; then
	cd ..
fi
if ! test -f "tools/weblate-create-projects-onetime-run.sh" ; then
	echo "Please call this script from yast-translations top directory."
	exit 1
fi
. tools/weblate-functions.inc

EOF

pushd $WORKDIR/po

generate base
for DOMAIN in * ; do
	if ! test -d $DOMAIN ; then
		continue
	fi
	# base must be created first
	if test $DOMAIN = base ; then
		continue
	fi
	generate $DOMAIN
done

popd
exec 3>&-
chmod +x tools/weblate-create-projects-onetime-run.sh

echo "tools/weblate-create-projects-onetime-run.sh is ready"
