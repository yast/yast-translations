#!/bin/sh

if ! test -f /usr/share/YaST2/data/devtools/bin/y2makepot ; then
	echo "Please install yast2-devtools!"
	exit 1
fi

cd ../yast-meta
git pull
export PATH=$PWD:$PATH
cd ../yast-checkout
y2m pull
cd ..

TRANDIR=$PWD/yast-translations

cd ../yast-checkout
shopt -s nullglob
for DIR in * ; do
	cd $DIR
	/usr/share/YaST2/data/devtools/bin/y2makepot
	for POT in *.pot ; do
		DOMAIN=${POT%.pot}
		mkdir -p $TRANDIR/$DOMAIN
		cp -a $POT $TRANDIR/$DOMAIN/
		cd $TRANDIR/$DOMAIN
		git add $POT
		for PO in *.po ; do
			msgmerge --previous --lang=${PO%.po} $PO $POT -o $PO.new
			mv $PO.new $PO
			git add $PO
		done
		git commit -m "Automatic update of $DOMAIN."
		cd -
	done
	cd ..
done
