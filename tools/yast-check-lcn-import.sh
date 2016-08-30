#!/bin/bash

cd ../yast-translations
shopt -s nullglob
for DIR in * ; do
	if ! test -d "$DIR" ; then
		continue
	fi
	if ! test -f "$DIR/$DIR.pot" ; then
		echo "$DIR: Missing $DIR.pot"
	fi
	HAS_PO=true
	eval test \" $DIR/*.po \" = \"\ \"
	if test $? = 0 ; then
		HAS_PO=false
	fi
	if ! $HAS_PO ; then
		echo "$DIR: No po files."
	fi
done
