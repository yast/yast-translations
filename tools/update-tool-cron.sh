#!/bin/bash
shopt -s nullglob
set -ex

# Find out if we are in a directory containing a yast2 full checkout.
if [ ! -d "translations/.git" ]; then
    echo "Please run this script in a directory containing a full checkout of yast2."
    exit 1
fi

WORKDIR=$PWD
TRANDIR=$WORKDIR/translations/po
TRANPARTS=$WORKDIR/translations/po-parts

# Check for the yast2-meta tool:
if ! Y2M=`command -v y2m`; then
    echo "The yast2 meta tool (y2m) is required to run this script."
    echo "Find it here: https://github.com/yast/yast-meta"
    exit 1
fi

# Check for y2makepot:
if ! Y2MAKEPOT=`command -v y2makepot`; then
    echo "y2makepot is required to run this script."
    echo "Find it here: https://github.com/yast/yast-devtools"
    exit 1
fi

# Creates all POT files within a given directory and copies them to a POT
# temporary directory, grouped by text domain, named by the source dir so that
# they can be merged into one POT file.
function make_pot {
    local MODULE_DIR=$1

    pushd $MODULE_DIR
    $Y2MAKEPOT
    for POT in *.pot ; do
	local DOMAIN=${POT%.pot}
	if grep -q "^$DOMAIN\\.pot$" $TRANDIR/OBSOLETE_POT_FILES; then
	    continue
	fi
	mkdir -p $TRANPARTS/$DOMAIN
	cp -a $POT $TRANPARTS/$DOMAIN/$MODULE_DIR.pot
    done
    popd
}

function merge_pot {
    local OUTFILE=$1
    shift
    local INFILES=$*

    # Use the POT headers from the first input file for the output file.
    msgcat --use-first $INFILES -o $OUTFILE
}

function strip_POT_dates {
    local INFILE=$1
    local OUTFILE=$2

    # Matches both, POT-Creation-Date and PO-Revision-Date. 
    sed '1,19{/^"PO.*ion-Date:/d}' <$INFILE >$OUTFILE
}

# main
# -------

# Pull all yast2 repositories:
#$Y2M pull

# Clear the POT target directory
rm -rf $TRANPARTS

# Create POT files for (nearly) all subdirectories
for DIR in * ; do
    [ "$DIR" != 'translations' ] || continue
    if grep -q "^$DIR\$" $TRANDIR/SKIP_PROJECTS; then
	continue
	fi
    make_pot $DIR
done

# Go to the POT temporary directory
cd $TRANPARTS

for DOMAIN in * ; do
    # This directory is most likely already there, but just to make sure ...
    mkdir -p $TRANDIR/$DOMAIN

    # get POT files
    POT_LIST=$DOMAIN/*.pot
    # We need to merge POT files in case there are several yast modules using
    # the same text domain.
    merge_pot $TRANDIR/$DOMAIN/$DOMAIN.pot.new $POT_LIST
    
    pushd $TRANDIR/$DOMAIN

    # Normalize the old POT files, because different gettext versions might
    # produce differently formatted lines.
    msgcat $DOMAIN.pot -o $DOMAIN.pot.old
    strip_POT_dates $DOMAIN.pot.old $DOMAIN.pot.old.nodate
    strip_POT_dates $DOMAIN.pot.new $DOMAIN.pot.new.nodate

    if cmp -s $DOMAIN.pot.old.nodate $DOMAIN.pot.new.nodate; then
	echo "No changes in $DOMAIN.pot. Skipping update."
	rm *.old *.nodate *.new
	popd
	continue
    fi

    echo "Updating $DOMAIN."
    # Remove the stripped POT files used for comparison.
    rm *.old *.nodate

    # Replace the old POT by the new one
    mv $DOMAIN.pot.new $DOMAIN.pot

    # Add it to the commit.
    git add $DOMAIN.pot

    # Merge the new POT into the existing PO files
    for PO in *.po ; do
        LANG=${PO%.po}
	if OUT=`msgmerge --previous --lang=$LANG $PO $DOMAIN.pot -o $PO.new 2>&1` ; then
	    mv $PO.new $PO

            # Add it to the commit.
	    git add $PO
        else
            # In case a real error occurred on merging, save the output of msgmerge
            echo "Error merging $LANG!"
            echo "$OUT" > $LANG.err
            # and count the errors
            ((ERR++))
        fi
    done
    # Make the commit
    git commit -m "New POT for text domain '$DOMAIN'."
    popd
done

if [ "$ERR" != "" ]; then
    echo "$ERR errors occurred. Check *.err files in the ./po/ subdirectory"
    exit $ERR
else
    echo "Success! Good bye!"
fi

