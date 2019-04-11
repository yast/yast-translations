#!/bin/sh
# rpm-groups is a bit different from other domains. It is created from output of other packages created by OBS.
# Run this script when you want to update it.
# Based on:
# (c) 2016 Aleksandr Melentev https://github.com/alexminton
# https://github.com/yast/yast-translations/pull/3#issuecomment-254150750
#
if test -d "yast-translations" ; then
	cd yast-translations
fi
if test -f "rpm-groups-pot-update.sh" ; then
	cd ..
fi

cd po/rpm-groups

curl -s https://raw.githubusercontent.com/openSUSE/packages-i18n/master/50-pot/rpm-groups.pot -o rpm-groups.pot

for PO in *.po ; do
	if msgmerge --previous --lang=${PO%.po} $PO rpm-groups.pot -o $PO.new ; then
		mv $PO.new $PO
	fi
done
