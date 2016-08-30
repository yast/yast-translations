#!/bin/bash -e

if ! test -e ../devtools/build-tools/scripts/y2makepot ; then
	echo "Please checkout yast properly"
	exit 1
fi

cd ..
meta/y2m pull

TRANDIR=$PWD/translations/po
y2makepot=$PWD/devtools/build-tools/scripts/y2makepot

shopt -s nullglob
for DIR in * ; do
	[ "$DIR" != 'translations' ] || continue
	pushd $DIR
	$y2makepot
	for POT in *.pot ; do
		DOMAIN=${POT%.pot}
		if grep -q "^$DOMAIN.pot" $TRANDIR/OBSOLETE_POT_FILES; then
			continue
		fi
		mkdir -p $TRANDIR/$DOMAIN
		cp -a $POT $TRANDIR/$DOMAIN/
		pushd $TRANDIR/$DOMAIN
		git add $POT
		for PO in *.po ; do
			msgmerge --previous --lang=${PO%.po} $PO $POT -o $PO.new
			mv $PO.new $PO
			git add $PO
		done
		git commit -m "Automatic update of $DOMAIN."
		popd
	done
	popd
done
