#!/bin/bash

shopt -s nullglob
for DIR in po/* ; do
	DOMAIN="${DIR##*/}"
	if ! test -d "$DIR" ; then
		continue
	fi
	if ! test -f "$DIR/$DOMAIN.pot" ; then
		echo "$DIR: Missing $DOMAIN.pot"
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
