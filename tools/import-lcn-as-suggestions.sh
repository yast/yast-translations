#!/bin/bash

# This tool imports diverged strings from SLE12 SP2 as suggestions to Weblate.
# It is not recommended to call it any more, as it will re-created refused suggestions.

set -e
set -o errexit
shopt -s nullglob

if test -d "yast-translations" ; then
	cd yast-translations
fi
if test -f "weblate-create-projects-onetime.sh" ; then
	cd ..
fi

# SLE12 SP2 will be used for strings that are untranslated in trunk
if ! test -d ../yast-sle12-sp2-r96945 ; then
	if test -d ../sle12-sp2 ; then
		cp -a ../sle12-sp2 ../sle12-sp2-r96945
		pushd ../yast-sle12-sp2-r96945 >/dev/null
		svn up -r96945
		popd >/dev/null
	else
		pushd .. >/dev/null
		svn checkout -r96945 https://svn.opensuse.org/svn/opensuse-i18n/branches/SLE12-SP2/yast yast-sle12-sp2-r96945
		popd >/dev/null
	fi
fi

# Update self as well
git pull

# Normalized directory of the initial Weblate stuff.
rm -rf ../yast-translations-suggestions
cp -a ../yast-translations ../yast-translations-suggestions

# Normalized directory of the initial Weblate stuff.
rm -rf ../yast-translations-sleonly-norm
cp -a ../yast-translations ../yast-translations-sleonly-norm

# Merge all sources to the reimport
exec 3>tools/import-lcn-as-suggestions-run.sh

cat >&3 <<EOF
#!/bin/bash

echo "This script was already executed. If cannot be started any more." >&2
exit 1

if test -f "import-lcn-as-suggestions-run.sh" ; then
	cd ..
fi
if ! test -f "tools/import-lcn-as-suggestions-run.sh" ; then
	echo "Please call this script from yast-translations top directory."
	exit 1
fi
. tools/weblate-functions.inc

EOF

cd ../yast-translations-suggestions/po
for PO in */*.po ; do
	FILENAME=${PO##*/}
	BASENAME=${FILENAME%.po}
	LNG=${FILENAME%.po}
	DOMAIN=${PO%/*}
	DOMAINSLE=$DOMAIN
	if test "$DOMAIN" = gtk-pkg ; then
		DOMAINSLE=gtk
	fi

	if test -f ../../yast-sle12-sp2-r96945/$LNG/po/$DOMAINSLE.$LNG.po ; then
		msgcat --use-first ../../yast-sle12-sp2-r96945/$LNG/po/$DOMAINSLE.$LNG.po $PO -o $PO.new
		msgmerge --no-fuzzy-matching --silent --previous --lang=$LNG $PO.new ../../yast-translations/po/$DOMAIN/$DOMAIN.pot -o $PO
		rm $PO.new
#BEGIN URL slug
		NAME=yast-$DOMAIN
		# special handling for textdomains starting by "yast2-"
		if test "${NAME#yast-yast2-}" != "$NAME" ; then
			NAME="yast-${NAME#yast-yast2-}"
		fi
		SLUG="$(echo $NAME | tr A-Z. a-z-)"
		if test -n "$(echo $SLUG | sed 's/[-a-z0-9_]//g')" ; then
			echo "Project URL slug \"$SLUG\" should contain only lowercase letters, \"-\" and \"_\"." >&2
			echo "Please fix or add a name convertor." >&2
			exit 1
		fi
#END URL slug
		echo >&3 "echo \"$SLUG master $LNG\""
		echo >&3 "weblate_upload_suggestions $SLUG master $LNG ../yast-translations-suggestions/po/$DOMAIN/$LNG.po"
	else
		rm $PO
	fi
done
exec 3>&-
chmod +x ../../yast-translations/tools/import-lcn-as-suggestions-run.sh

# This is not really needed, but it makes possible to make effective diff
cd ../../yast-translations-sleonly-norm/po
for PO in */*.po ; do
	FILENAME=${PO##*/}
	BASENAME=${FILENAME%.po}
	LNG=${FILENAME%.po}
	DOMAIN=${PO%/*}
	DOMAINSLE=$DOMAIN
	if test "$DOMAIN" = gtk-pkg ; then
		DOMAINSLE=gtk
	fi

	if test -f ../../yast-sle12-sp2-r96945/$LNG/po/$DOMAINSLE.$LNG.po ; then
		msgcat --use-first $PO ../../yast-sle12-sp2-r96945/$LNG/po/$DOMAINSLE.$LNG.po -o $PO.new
		msgmerge --no-fuzzy-matching --silent --previous --lang=$LNG $PO.new ../../yast-translations/po/$DOMAIN/$DOMAIN.pot -o $PO
		rm $PO.new
	else
		rm $PO
	fi
done
cd ../..

# This diff has no use in the process. It is just for quick check.
diff -ur yast-translations-sleonly-norm yast-translations-suggestions >suggestions.diff || :

echo "tools/import-lcn-as-suggestions-run.sh is ready"

echo "Please disable mail notifications by temporary setting"
echo "EMAIL_BACKEND = 'django.core.mail.backends.dummy.EmailBackend' in /etc/weblate/settings.py"
echo "Please call the script by:"
echo "tools/import-lcn-as-suggestions-run.sh 2>>import-lcn-as-suggestions-run.log"
echo "to keep list of emails you need to notify."
