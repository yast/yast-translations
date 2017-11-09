#!/bin/bash
#
# This script checks relation between the yast-translations package and
# packages existing in selected product.
#
# Remember to run update-tool.sh to ensure that all projects are in l10n.
# This check is not included here.

APIURL=
REPO=openSUSE:Leap:15.0

# This is for SLE 15 inside the intranet
#APIURL=https://api.suse.de/
#REPO=SUSE:SLE-15:GA

set -o errexit
shopt -s nullglob

if test "$1" = "--debug" ; then
	DEBUG=true
else
	DEBUG=false
fi
if $DEBUG ; then
function DBG() {
	echo >&2 "$*"
}
else
function DBG() {
	:
}
fi

if test -f "product-check.sh" ; then
	cd ..
fi
if ! test -f "tools/product-check.sh" ; then
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

osc ${APIURL:+ -A $APIURL} ls $REPO | sed -n 's/^yast2-//p' >product-check-list-repo.lst
cd $YAST_CHECKOUT
ls -1 | grep -x -F -v yast.github.io >$OLDPWD/product-check-list-checkout.lst
cd - >/dev/null

DBG "Check 1: Are all packages properly translated?"
DBG "=============================================="
exec <product-check-list-repo.lst
while read PACKAGE ; do
	DBG "Checking $PACKAGE..."
	if test $PACKAGE = ruby-bindings ; then
		DBG "  skipping (see https://bugzilla.suse.com/show_bug.cgi?id=1066999)"
		continue
	fi
	if grep -q -x -F "$PACKAGE" product-check-list-checkout.lst ; then
		DBG "  found in checkout"
		if test -d "$YAST_CHECKOUT/$PACKAGE" ; then
			cd $YAST_CHECKOUT/$PACKAGE
			for DOMAIN in *.pot ; do
				DOMAIN=${DOMAIN%.pot}
				DBG "    checking $DOMAIN..."
				if ! test -d $OLDPWD/po/$DOMAIN ; then
					echo "$PACKAGE is in product and checkout, but $DOMAIN is not in yast-translations."
				fi
				if grep -q -x -F "$DOMAIN.pot" $OLDPWD/po/OBSOLETE_POT_FILES ; then
					echo "$PACKAGE is in product and checkout, but $DOMAIN is in po/OBSOLETE_POT_FILES."
				fi
			done
			cd - >/dev/null
		else
			echo "$PACKAGE is in product, but missing in checkout"
		fi
	fi
	if grep -q -x -F "$PACKAGE" po/SKIP_PROJECTS ; then
		echo "$PACKAGE is in product and checkout, but also in SKIP_PROJECTS"
	fi
done

DBG "Check 2: Are all domains in yast-translations really used?"
DBG "=========================================================="
cd po
for DOMAIN in * ; do
	DBG "Checking $DOMAIN..."
	if ! test -d "$DOMAIN" ; then
		continue
	fi
	if grep -q -x -F "$DOMAIN.pot" OBSOLETE_POT_FILES ; then
		echo "$DOMAIN is in po, but it is also in OBSOLETE_POT_FILES."
	fi
	# Major package is a package that contains majority of strings in the domain.
	MAJOR_PACKAGE=$(sed -n "s/^$DOMAIN //p" <DOMAIN_MAP)
	if test -z "$MAJOR_PACKAGE" ; then
		echo "$DOMAIN is in po, but missing in DOMAIN_MAP."
	else
		if test "$MAJOR_PACKAGE" != "base" ; then
			if ! grep -q -x -F "$MAJOR_PACKAGE" $OLDPWD/product-check-list-checkout.lst ; then
				echo "$DOMAIN is in po, but corresponding $MAJOR_PACKAGE from DOMAIN_MAP is not present in checkout."
			fi
		fi
	fi
	LS="$(cd $YAST_CHECKOUT ; compgen -G "*/$DOMAIN.pot" || :)"
	PACKAGES=( $(echo -n "$LS" | sed "s:/.*::" ) )
	if test ${#PACKAGES[@]} -eq 0 ; then
		echo "$DOMAIN is in po, but no corresponding package in yast-checkout exists."
	fi
	DBG "  maps to ${PACKAGES[*]}..."
	for PACKAGE in "${PACKAGES[@]}" ; do
		if test ${#PACKAGES[@]} -eq 1 ; then
			MAJOR_STRING="all"
		elif test "$PACKAGE" = "$MAJOR_PACKAGE" ; then
			MAJOR_STRING="most"
		else
			MAJOR_STRING="some"
		fi
		DBG "    package $PACKAGE..."
		if grep -q -x -F "$PACKAGE" SKIP_PROJECTS ; then
			echo "$DOMAIN is in po, but corresponding $PACKAGE with $MAJOR_STRING strings is also in SKIP_PROJECTS."
		fi
		if test "$PACKAGE" != "base" ; then
			if ! grep -q -x -F "$PACKAGE" $OLDPWD/product-check-list-repo.lst ; then
				echo "$DOMAIN is in po, but corresponding yast2-$PACKAGE with $MAJOR_STRING strings is not present in repo."
			fi
		fi
	done
done
cd - >/dev/null

# Check 3: Are all packages in yast-checkout translated? This check is
# done by update-tool.sh, not here!

rm -f product-check-list-checkout.lst product-check-list-repo.lst
