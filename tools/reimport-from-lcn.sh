#!/bin/bash

# This tool is for demonstration only. It was used only once, and will never be.
# It is a good source of a safe merge of translations from different sources.

set -e
set -o errexit
shopt -s nullglob

if test -d "yast-translations" ; then
	cd yast-translations
fi
if test -f "weblate-create-projects-onetime.sh" ; then
	cd ..
fi

# First update yast LCN snapshots
if ! test -d ../yast-trunk ; then
	svn checkout https://svn.opensuse.org/svn/opensuse-i18n/trunk/yast yast-trunk
else
	pushd ../yast-sle12-sp2 >/dev/null
	svn update
	popd >/dev/null
fi
# SLE12 SP2 will be used for strings that are untranslated in trunk
if ! test -d ../yast-sle12-sp2 ; then
	svn checkout https://svn.opensuse.org/svn/opensuse-i18n/branches/SLE12-SP2/yast yast-sle12-sp2
else
	pushd ../yast-sle12-sp2 >/dev/null
	svn update
	popd >/dev/null
fi

# Update self as well
git pull

# Create copy of initial import
if ! test -d ../yast-translations-initial ; then
	cp -a ../yast-translations ../yast-translations-initial
	pushd ../yast-translations-initial >/dev/null
	git checkout 1cc1652f022e4f4987c3ab46bd940ad96f993dc8
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
cp -a ../yast-translations ../yast-translations-current-norm
# Normalized reimport directory. We will merge changes from LCN gere.
rm -rf ../yast-translations-reimport-norm
cp -a ../yast-translations ../yast-translations-reimport-norm
# This will be the final directory, where we will perform the push.
rm -rf ../yast-translations-push
cp -a ../yast-translations ../yast-translations-push

# Merge all sources to the reimport (
cd ../yast-translations-reimport-norm/po
for PO in */*.po ; do
	FILENAME=${PO##*/}
	BASENAME=${FILENAME%.po}
	LNG=${FILENAME%.po}
	DOMAIN=${PO%/*}

	if test -f ../../yast-sle12-sp2/$LNG/po/$DOMAIN.$LNG.po ; then
		msgcat --use-first $PO ../../yast-trunk/$LNG/po/$DOMAIN.$LNG.po ../../yast-sle12-sp2/$LNG/po/$DOMAIN.$LNG.po -o $PO.new
	else
		msgcat --use-first $PO ../../yast-trunk/$LNG/po/$DOMAIN.$LNG.po -o $PO.new
	fi
	mv $PO.new $PO
done

cd ../..
for PROJECT in *-norm ; do
	cd $PROJECT/po
	for DIR in * ; do
		if ! test -d "$DIR" ; then
			continue
		fi
		# Simply ignore projects with no pot file / not currently existing
		if ! test -f ../../yast-translations/po/$DIR/$DIR.pot ; then
			echo "Ignoring $DIR in $PROJECT: no pot file" >&2
			continue
		fi
		pushd $DIR >/dev/null
		for PO in *.po ; do
			msgattrib --no-fuzzy --force-po $PO -o $PO.new
			msgmerge --no-fuzzy-matching --silent --previous --lang=${PO%.po} $PO.new ../../../yast-translations/po/$DIR/$DIR.pot -o $PO
			rm $PO.new
		done
		popd >/dev/null
	done
	cd ../..
done

# This diff has no use in the process. It is just for quick check.
diff -ur yast-translations-current-norm yast-translations-reimport-norm >reimport.diff || :

# Now we are finally ready for the reimport. Use some gettext magic to separate
# changes to non conflicting additions and conflicting changes.

cd yast-translations-reimport-norm/po
for PO in */*.po ; do
	if test -f ../../yast-translations/po/$PO ; then

		# Existing translation. Split to additions and conflicts.

		# .current-first will contain current, only missing strings will be taken from reimport.
		msgcat --force-po --use-first ../../yast-translations-current-norm/po/$PO ../../yast-translations-reimport-norm/po/$PO -o $PO.current-first
		# Then all unique strings comparing to the current-norm are additions. Changes are lost here.
		# We are not adding --force-po: If there is no such string, nothing is written.
		msgcat --less-than=2 $PO.current-first ../../yast-translations-current-norm/po/$PO -o ../../yast-translations-push/po/$PO.joinme

		# Similar as above, but without --use-first, all conflicting translations will become fuzzy in .join.
		msgcat --force-po ../../yast-translations-current-norm/po/$PO ../../yast-translations-reimport-norm/po/$PO -o $PO.join
		# Then all unique strings comparing to the current-norm are additions. Changes are lost here.
		# We are not adding --force-po: If there is no such string, nothing is written.
		msgattrib --only-fuzzy $PO.join -o ../../yast-translations-push/po/$PO.conflict

		if test -f ../../yast-translations-push/po/$PO.joinme ; then
			# Merge additions automatically.
			pushd ../../yast-translations-push/po >/dev/null
			# --use-first is not needed, strings should be unique. But it is safe.
			msgcat --use-first ../../yast-translations-push/po/$PO.joinme ../../yast-translations-push/po/$PO -o ../../yast-translations-push/po/$PO.new
			mv ../../yast-translations-push/po/$PO.new ../../yast-translations-push/po/$PO
			git add $PO
			popd >/dev/null
		fi

	else
		# Completely new translation
		LNG=${PO#*/}
		LNG=${LNG%.po}
		msgmerge --silent --previous --lang=$LNG $PO ../../../yast-translations/po/$DIR/$DIR.pot -o ../../yast-translations-push/po/$PO.addme
		pushd ../../yast-translations-push/po >/dev/null
		cp -a ../../yast-translations-push/po/$PO.addme ../../yast-translations-push/po/$PO
		git add $PO
		popd >/dev/null
	fi
done

cd ../..

echo "Everything is done. Please do \"git commit\" and then \"git push\" in yast-translations-push,"
echo "and search for files named *.conflict by find -name \"*.conflict\"."
echo "If it will succeed, remove files from LCN. To prevent conflicts, use the current snapshot in yast-trunk."
