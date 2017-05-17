#!/bin/bash

# Note: Do not call this script inside translations repo in read-only checkout!
# Make R/W checkout instead.

BRANCH=master

set -o errexit

# weblate_create yast_textdomain branch
function weblate_create() {
	local YAST_PROJECT YAST_BRANCH
	if test -n "$2" ; then
		YAST_BRANCH=$2
	else
		YAST_BRANCH=master
	fi
	# Ugly hack! We want openSUSE for master.
	case "$1/$YAST_BRANCH" in
	control/master )
		YAST_PROJECT=skelcd-control-openSUSE
		;;
	* )
		YAST_PROJECT=$(sed -n "s/^$1 //p" <$WORKDIR/po/DOMAIN_MAP)
		;;
	esac

	local WEBLATE_PROJECT=yast-$PROJECT
	# special handling for textdomains starting by "yast2-"
	if test "${WEBLATE_PROJECT#yast-yast2-}" != "$WEBLATE_PROJECT" ; then
		WEBLATE_PROJECT="yast-${WEBLATE_PROJECT#yast-yast2-}"
	fi

	local PROJECT_NAME=yast-$1
	# special handling for textdomains starting by "yast2-"
	if test "${PROJECT_NAME#yast-yast2-}" != "$PROJECT_NAME" ; then
		PROJECT_NAME="yast-${PROJECT_NAME#yast-yast2-}"
	fi
	local PROJECT_SLUG="$(echo $PROJECT_NAME | tr A-Z. a-z-)"
	if test -n "$(echo $PROJECT_SLUG | sed 's/[-a-z0-9_]//g')" ; then
		echo "Project URL slug \"$PROJECT_SLUG\" should contain only lowercase letters, \"-\" and \"_\"." >&2
		echo "Please fix or add a name convertor." >&2
		exit 1
	fi
	local BRANCH_NAME=$2
	local BRANCH_SLUG="$(echo $BRANCH_NAME | tr A-Z. a-z-)"
	if test -n "$(echo $BRANCH_SLUG | sed 's/[-a-z0-9_]//g')" ; then
		echo "Component URL slug \"$SLUG\" should contain only lowercase letters, \"-\" and \"_\"." >&2
		echo "Please fix or add a name convertor." >&2
		exit 1
	fi

	if ! curl -f -I https://l10n.opensuse.org/projects/$PROJECT_SLUG/ >/dev/null 2>&1 ; then
		weblate_create_project $1 $YAST_PROJECT
	fi
	if ! curl -f -I https://l10n.opensuse.org/projects/$PROJECT_SLUG/$BRANCH_SLUG/ >/dev/null 2>&1 ; then
		weblate_create_component $1 $YAST_PROJECT $YAST_BRANCH
	fi
}

if test -f "update-tool.sh" ; then
	cd ..
fi
if ! test -f "tools/update-tool.sh" ; then
	echo "Please call this script from yast-translations top directory."
	exit 1
fi
. tools/weblate-functions.inc
WORKDIR=$PWD


YAST_CHECKOUT=
for DIR in ~ "$PWD"/.. ; do
	if test -d $DIR/yast-checkout ; then
		YAST_CHECKOUT=$DIR/yast-checkout
	fi
done
if test -z "$YAST_CHECKOUT" ; then
	echo "No yast-checkout find. Do you want to do the checkout now? (Y/n)"
	read
	if test "$REPLY" = n ; 	then
		exit 1
	fi
	mkdir ../yast-checkout-temp
	cd ../yast-checkout-temp
	git clone https://github.com/yast/yast-meta

	mkdir ~/yast-checkout
	cd ~/yast-checkout
	$OLDPWD/../yast-checkout-temp/yast-meta/y2m read-only ALL
	YAST_CHECKOUT=$PWD

	rm -rf $OLDPWD/../yast-checkout-temp
fi

TRANDIR=$WORKDIR/po
TRANPARTS=$WORKDIR/po-parts
Y2MAKEPOT=$YAST_CHECKOUT/devtools/build-tools/scripts/y2makepot
Y2M=$YAST_CHECKOUT/meta/y2m

cd $YAST_CHECKOUT

$Y2M pull

shopt -s nullglob

rm -rf $TRANPARTS
for DIR in * ; do
	[ "$DIR" != 'translations' ] || continue
	if grep -q "^$DIR\$" $TRANDIR/SKIP_PROJECTS; then
		continue
	fi
	pushd $DIR >/dev/null
	rm -f *.pot
	$Y2MAKEPOT
	for POT in *.pot ; do
		DOMAIN=${POT%.pot}
		if grep -q "^$DOMAIN\\.pot$" $TRANDIR/OBSOLETE_POT_FILES; then
			continue
		fi
		mkdir -p $TRANPARTS/$DOMAIN
		cp -a $POT $TRANPARTS/$DOMAIN/$DIR.pot
	done
	popd >/dev/null
done

cd $TRANPARTS
rm -f $TRANDIR/DOMAIN_MAP
for DOMAIN in * ; do
	mkdir -p $TRANDIR/$DOMAIN
	# This is an ugly hack: Use the newest file as source of header
	msgcat --use-first $(ls -1 --sort=time $DOMAIN/*.pot) -o $TRANDIR/$DOMAIN/$DOMAIN.pot.new
	# DOMAIN_MAP is used for source reference. Use the project with largest pot file.
	echo $DOMAIN $(cd $DOMAIN ; ls -1 --sort=size *.pot | head -n1 | sed s/\\.pot\$// ) >>$TRANDIR/DOMAIN_MAP
	weblate_create $DOMAIN $BRANCH
	pushd $TRANDIR/$DOMAIN >/dev/null
	# prevent re-committing when pot file uses different line format
	msgcat $DOMAIN.pot -o $DOMAIN.pot.tmp
	sed '1,11{/^"POT-Creation-Date:/d};1,12{/^"PO-Revision-Date:/d}' <$DOMAIN.pot.tmp >$DOMAIN.pot.nodate
	sed '1,11{/^"POT-Creation-Date:/d};1,12{/^"PO-Revision-Date:/d}' <$DOMAIN.pot.new >$DOMAIN.pot.new.nodate
	if cmp -s $DOMAIN.pot.nodate $DOMAIN.pot.new.nodate ; then
		echo "No changes in $DOMAIN.pot. Skipping update."
		rm *.tmp *.nodate *.new
		popd >/dev/null
		continue
	fi
	echo "Updating $DOMAIN."
	rm *.tmp *.nodate
	mv $DOMAIN.pot.new $DOMAIN.pot
	git add $DOMAIN.pot
	for PO in *.po ; do
		msgmerge --previous --lang=${PO%.po} $PO $DOMAIN.pot -o $PO.new
		mv $PO.new $PO
		git add $PO
	done
	git commit -m "Automatic update of $DOMAIN."
	popd >/dev/null

done

echo "If everything went OK, call \"git push\"."
