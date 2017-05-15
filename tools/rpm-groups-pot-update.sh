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

exec >rpm-groups.pot
echo '# This file was automatically generated'
echo 'msgid ""'
echo 'msgstr ""'
echo '"Project-Id-Version: rpm-groups\n"'
echo '"Report-Msgid-Bugs-To: bugzilla.opensuse.org\n"'
echo "\"POT-Creation-Date: $(date "+%F %R%z")\\n\""
echo "\"PO-Revision-Date: $(date "+%F %R%z")\\n\""
echo '"Last-Translator: Automatically generated\n"'
echo '"Language-Team: openSUSE <opensuse-translation@opensuse.org>\n"'
echo '"Language: en\n"'
echo '"MIME-Version: 1.0\n"'
echo '"Content-Type: text/plain; charset=UTF-8\n"'
echo '"Content-Transfer-Encoding: 8bit\n"'
curl -s http://downloadcontent.opensuse.org/tumbleweed/repo/oss/suse/setup/descr/packages.gz |
	gzip -c -d |
	sed -n -e 's/=Grp: //gp' |
	sed -e 's:/:\n:g' |
	LC_ALL=en_US.UTF-8 sort -u |
	while IFS='' read -r LINE ; do
		[ -n "$LINE" ] && echo "" && echo "msgid \"$LINE\"" && echo 'msgstr ""'
	done
exec >&-

for PO in *.po ; do
	if msgmerge --previous --lang=${PO%.po} $PO rpm-groups.pot -o $PO.new ; then
		mv $PO.new $PO
	fi
done
