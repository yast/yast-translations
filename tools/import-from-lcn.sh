#!/bin/bash

TRANDIR=$PWD/../yast-translations

cd ../yast-lcn
svn up

for PO in */*/*.po ; do
	FILENAME=${PO##*/}
	BASENAME=${FILENAME%.po}
	LNG=${PO%%/*}
	DOMAIN=${BASENAME%.$LNG}
	mkdir -p $TRANDIR/$DOMAIN
	cp -a $PO $TRANDIR/$DOMAIN/$LNG.po
	chmod 0644 $TRANDIR/$DOMAIN/$LNG.po
done

cd $TRANDIR
git add */*.po
git commit -m "Import all po files from LCN."
git push
