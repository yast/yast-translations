#!/bin/bash

APIURL=
REPO=openSUSE:Leap:15.0

set -o errexit
shopt -s nullglob

DEBUG=false
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

exec <product-check-list-repo.lst
while read PACKAGE ; do
	DBG "Checking $PACKAGE..."
	if grep -q -x -F "$PACKAGE" product-check-list-checkout.lst ; then
		DBG "  found in checkout"
		if test -d "$YAST_CHECKOUT/$PACKAGE" ; then
			cd $YAST_CHECKOUT/$PACKAGE
			for DOMAIN in *.pot ; do
				DBG "    checking $DOMAIN..."
				if test -d $OLDPWD/po/$DOMAIN ; then
					echo "$PACKAGE in product and checkout, but $DOMAIN is not in yast-translations"
				fi
				if grep -q -x -F "$DOMAIN" $OLDPWD/po/OBSOLETE_POT_FILES ; then
					echo "$PACKAGE in product and checkout, but $DOMAIN in OBSOLETE_POT_FILES"
				fi
			done
			cd - >/dev/null
		else
			echo "$PACKAGE in product, but missing in checkout"
		fi
	fi
	if grep -q -x -F "$PACKAGE" po/SKIP_PROJECTS ; then
		echo "$PACKAGE in product and checkout, but in SKIP_PROJECTS"
	fi
done

rm -f product-check-list-checkout.lst product-check-list-repo.lst
