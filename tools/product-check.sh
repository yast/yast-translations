#!/bin/bash
#
# This script checks relation between the yast-translations package and
# packages existing in selected product.
#
# Remember to run update-tool.sh to ensure that all projects are in l10n.
# This check is not included here.

APIURL=
REPO=openSUSE:Leap:15.4

# For Tumbleweed
APIURL=
REPO=openSUSE:Factory

# This is for SLE 15 inside the intranet
APIURL=https://api.suse.de/
REPO=SUSE:SLE-15-SP4:GA

# Check product
# true: check packages listed in 000product package.
# false: Do not check 000product. List all packages in the project and inherited projects.
CHECK_PRODUCT=true
# TODO: CHECK_PRODUCT=false does not support check for packages introduced by online update and later inherited.

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

function rpmname() {
	(
		cd $YAST_CHECKOUT
		if test -f "$1/RPMNAME" ; then
			cat $1/RPMNAME
		else
			echo $1
		fi
	)
}

function gitname() {
	(
		cd $YAST_CHECKOUT
		NAME=$(grep -l -x -F $1 */RPMNAME | sed s:/RPMNAME::)
		if test -n "$NAME" ; then
			echo $NAME
		else
			echo "$1"
		fi
	)
}

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

if $CHECK_PRODUCT ; then
	osc ${APIURL:+ -A $APIURL} co $REPO 000product
	cat $REPO/000product/*.kiwi | sed -n 's:.*<repopackage name="\([^"]*\)"/>:\1:p' | sort -u >product-check-list-repo.lst
	rm -r $REPO
else
	osc ${APIURL:+ -A $APIURL} ls -e $REPO >product-check-list-repo.lst
fi
cd $YAST_CHECKOUT
ls -1 | grep -x -F -v yast.github.io >$OLDPWD/product-check-list-checkout.lst
cd - >/dev/null

DBG "Check 1: Are all packages properly translated?"
DBG "=============================================="
exec <product-check-list-repo.lst
while read RPMNAME ; do
	GITNAME=$(gitname $RPMNAME)

	if test -z "$GITNAME" ; then
		continue
	fi
	DBG "Checking $RPMNAME (GitHub $GITNAME)..."
	if test $GITNAME = ruby-bindings ; then
		DBG "  skipping (see https://bugzilla.suse.com/show_bug.cgi?id=1066999)"
		continue
	fi
	if grep -q -x -F "$GITNAME" product-check-list-checkout.lst ; then
		DBG "  found in checkout"
		if test -d "$YAST_CHECKOUT/$GITNAME" ; then
			cd $YAST_CHECKOUT/$GITNAME
			for DOMAIN in *.pot ; do
				DOMAIN=${DOMAIN%.pot}
				DBG "    checking $DOMAIN..."
				if ! test -d $OLDPWD/po/$DOMAIN ; then
					echo "$RPMNAME is in product, $GITNAME in checkout, but $DOMAIN is not in yast-translations."
				fi
				if grep -q -x -F "$DOMAIN.pot" $OLDPWD/po/OBSOLETE_POT_FILES ; then
					echo "$RPMNAME is in product, $GITNAME in checkout, but $DOMAIN is in po/OBSOLETE_POT_FILES."
				fi
			done
			cd - >/dev/null
		else
			echo "$RPMNAME is in product, but $GITNAME missing in checkout"
		fi
	fi
	if grep -q -x -F "$GITNAME" po/SKIP_PROJECTS ; then
		echo "$RPMNAME is in product, $GITNAME in checkout, but also in SKIP_PROJECTS"
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
	# rpm-groups is not associater with any package
	if test "$DOMAIN" = rpm-groups ; then
		continue
	fi
	if grep -q -x -F "$DOMAIN.pot" OBSOLETE_POT_FILES ; then
		echo "$DOMAIN is in po, but it is also in OBSOLETE_POT_FILES."
	fi
	# Major package is a package that contains majority of strings in the domain.
	MAJOR_GITNAME=$(sed -n "s/^$DOMAIN //p" <DOMAIN_MAP)
	if test -z "$MAJOR_GITNAME" ; then
		echo "$DOMAIN is in po, but missing in DOMAIN_MAP."
	else
		MAJOR_RPMNAME=$(rpmname $MAJOR_GITNAME)
		if ! grep -q -x -F "$MAJOR_GITNAME" $OLDPWD/product-check-list-checkout.lst ; then
			echo "$DOMAIN from is in po, but package $MAJOR_RPMNAME corresponding to project $MAJOR_GITNAME from DOMAIN_MAP is not present in checkout."
		fi
	fi
	LS="$(cd $YAST_CHECKOUT ; compgen -G "*/$DOMAIN.pot" || :)"
	GITNAMES=( $(echo -n "$LS" | sed "s:/.*::" ) )
	if test ${#GITNAMES[@]} -eq 0 ; then
		echo "$DOMAIN is in po, but no corresponding project in yast-checkout exists."
	fi
	DBG "  maps to ${GITNAMES[*]}..."
	for GITNAME in "${GITNAMES[@]}" ; do
		RPMNAME=$(rpmname $GITNAME)
		if test ${#GITNAMES[@]} -eq 1 ; then
			MAJOR_STRING="all"
		elif test "$GITNAME" = "$MAJOR_GITNAME" ; then
			MAJOR_STRING="most"
		else
			MAJOR_STRING="some"
		fi
		DBG "    package $GITNAME (rpm $RPMNAME)..."
		if grep -q -x -F "$GITNAME" SKIP_PROJECTS ; then
			echo "$DOMAIN is in po, but package $MAJOR_RPMNAME corresponding to project$GITNAME with $MAJOR_STRING strings is also in SKIP_PROJECTS."
		fi

		if ! grep -q -x -F "$RPMNAME" $OLDPWD/product-check-list-repo.lst ; then
			echo "$DOMAIN is in po, but package $MAJOR_RPMNAME corresponding to project $GITNAME with $MAJOR_STRING strings is not present in repo."
		fi
	done
done
cd - >/dev/null

# Check 3: Are all packages in yast-checkout translated? This check is
# done by update-tool.sh, not here!

rm -f product-check-list-checkout.lst product-check-list-repo.lst
