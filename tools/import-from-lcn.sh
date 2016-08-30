#!/bin/bash
set -e

if [ ! -d yast-lcn ]; then
	echo "please svn checkout https://svn.opensuse.org/svn/opensuse-i18n/trunk/yast/ yast-lcn"
	exit 1
fi

if [ ! -d yast-lcn-sp2 ]; then
	echo "please svn checkout https://svn.opensuse.org/svn/opensuse-i18n/branches/SLE12-SP2/yast"
	exit 1
fi

TRANDIR="$PWD/po"
mkdir $TRANDIR

pushd yast-lcn-sp2
svn up
popd
pushd yast-lcn
svn up

cp 50-pot/OBSOLETE_POT_FILES $TRANDIR

for PO in */*/*.po ; do
	FILENAME=${PO##*/}
	BASENAME=${FILENAME%.po}
	LNG=${PO%%/*}
	DOMAIN=${BASENAME%.$LNG}
	if grep -q "^$DOMAIN.pot" $TRANDIR/OBSOLETE_POT_FILES; then
		#echo "obsolete $DOMAIN"
		continue
	fi
	mkdir -p $TRANDIR/$DOMAIN
	if [  -e ../yast-lcn-sp2/$PO ]; then
		#echo "merge $DOMAIN $LNG"
		msgcat --use-first $PO ../yast-lcn-sp2/$PO -o $TRANDIR/$DOMAIN/$LNG.po
	else
		#echo "copy $DOMAIN $LNG"
		cp -a $PO $TRANDIR/$DOMAIN/$LNG.po
	fi
	chmod 0644 $TRANDIR/$DOMAIN/$LNG.po
done

popd
git add $TRANDIR
git commit -m "Import all po files from LCN."
