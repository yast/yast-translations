#!/bin/bash

# This tool is a nearly clone of reimport-from-lcn.sh. It was used only once, and will never be.
# It is a good source of a safe merge of translations from different sources.
# Collects contribution from both imports.

set -e
set -o errexit
shopt -s nullglob

if test -d "yast-translations" ; then
	cd yast-translations
fi
if test -f "weblate-create-projects-onetime.sh" ; then
	cd ..
fi

# First update last yast LCN snapshots
if ! test -d ../yast-trunk-r96945 ; then
	if test -d ../yast-trunk ; then
		cp -a ../yast-trunk ../yast-trunk-r96945
		pushd ../yast-trunk-r96945 >/dev/null
		svn up -r96945
		popd >/dev/null
	else
		pushd .. >/dev/null
		svn checkout -r96945 https://svn.opensuse.org/svn/opensuse-i18n/trunk/yast yast-trunk-r96945
		popd >/dev/null
	fi
fi

# SLE12 SP2 will be used for strings that are untranslated in trunk
if ! test -d ../yast-sle12-sp2-r96945 ; then
	if test -d ../sle12-sp2 ; then
		cp -a ../sle12-sp2 ../sle12-sp2-r96945
		pushd ../yast-sle12-sp2-r96945 >/dev/null
		svn up -r96945
		popd >/dev/null
	else
		pushd .. >/dev/null
		svn checkout -r96945 https://svn.opensuse.org/svn/opensuse-i18n/branches/SLE12-SP2/yast yast-sle12-sp2-r96945
		popd >/dev/null
	fi
fi

# Create copy of initial import
if ! test -d ../yast-translations-initial ; then
	cp -a ../yast-translations ../yast-translations-initial
	pushd ../yast-translations-initial >/dev/null
	git checkout 1cc1652f022e4f4987c3ab46bd940ad96f993dc8
	popd >/dev/null
fi

# Create copy of initial import
if ! test -d ../yast-translations-reimported ; then
	cp -a ../yast-translations ../yast-translations-reimported
	pushd ../yast-translations-reimported >/dev/null
	git checkout 2ad39671be8e6929a6dc4d26b1115a47d06f1fa3
	popd >/dev/null
fi

# po files made by different tools cannot be compared directly due to different formatting
# Also po files corresponding to a different pot file cannot be compared directly
# => We need to normalize all of them. But initial import did not contain pot files.
# And even later files were maybe incorrect (yast devtools commit fc9bedb2).
# So we will process all po files against current pot files.

# Normalized directory of the initial Weblate stuff.
rm -rf ../yast-translations-initial-norm
cp -a ../yast-translations-initial ../yast-translations-initial-norm
# Normalized directory of current Weblate stuff.
rm -rf ../yast-translations-current-norm
cp -a ../yast-translations-reimported ../yast-translations-reimported-norm
# Normalized reimport directory. We will merge changes from LCN here.
rm -rf ../yast-translations-reimported-norm
cp -a ../yast-translations-reimported ../yast-translations-reimported-norm
# Normalized reimport directory. We will merge changes from LCN here.
rm -rf ../yast-translations-reimported-norm-nosle
cp -a ../yast-translations-reimported ../yast-translations-reimported-norm-nosle
# This will be the final directory, where we will perform the push.
rm -rf ../yast-translations-sle-contributions
mkdir -p yast-translations-sle-contributions

# Merge all sources to the reimport
cd ../yast-translations-reimported-norm/po
for PO in */*.po ; do
	FILENAME=${PO##*/}
	BASENAME=${FILENAME%.po}
	LNG=${FILENAME%.po}
	DOMAIN=${PO%/*}

	if test -f ../../yast-sle12-sp2-r96945/$LNG/po/$DOMAIN.$LNG.po ; then
		msgcat --use-first ../../yast-trunk-r96945/$LNG/po/$DOMAIN.$LNG.po ../../yast-sle12-sp2-r96945/$LNG/po/$DOMAIN.$LNG.po -o $PO.new
		mv $PO.new $PO
	else
		rm $PO
	fi
done

# Merge all sources without SLE to the reimport
cd ../../yast-translations-reimported-norm-nosle/po
for PO in */*.po ; do
	FILENAME=${PO##*/}
	BASENAME=${FILENAME%.po}
	LNG=${FILENAME%.po}
	DOMAIN=${PO%/*}

	if test -f ../../yast-sle12-sp2-r96945/$LNG/po/$DOMAIN.$LNG.po ; then
		msgcat --use-first ../../yast-trunk-r96945/$LNG/po/$DOMAIN.$LNG.po -o $PO.new
		mv $PO.new $PO
	else
		rm $PO
	fi
done

cd ../..
for PROJECT in *reimported-norm* ; do
	cd $PROJECT/po
	for DIR in * ; do
		if ! test -d "$DIR" ; then
			continue
		fi
		# Simply ignore projects with no pot file / not currently existing
		if ! test -f ../../yast-translations-reimported/po/$DIR/$DIR.pot ; then
			echo "Ignoring $DIR in $PROJECT: no pot file" >&2
			continue
		fi
		pushd $DIR >/dev/null
		for PO in *.po ; do
			msgattrib --no-fuzzy --force-po $PO -o $PO.new
			msgmerge --no-fuzzy-matching --silent --previous --lang=${PO%.po} $PO.new ../../../yast-translations-reimported/po/$DIR/$DIR.pot -o $PO
			rm $PO.new
		done
		popd >/dev/null
	done
	cd ../..
done

# This diff has no use in the process. It is just for quick check.
diff -ur yast-translations-reimported-norm-nosle yast-translations-reimported-norm >reimported-sle.diff || :

# Now we are finally ready for the comparison. Use some gettext magic to separate
# SLE additions.

cd yast-translations-reimported-norm/po
for PO in */*.po ; do
	mkdir -p ../../yast-translations-sle-contributions/${PO%/*}
	msgcat --less-than=2 $PO ../../yast-translations-reimported-norm-nosle/po/$PO -o ../../yast-translations-sle-contributions/$PO
done

cd ../../yast-translations-sle-contributions
rmdir --ignore-fail-on-non-empty *

echo "Everything is done. Please upload yast-translations-sle-contributions somewhere."
