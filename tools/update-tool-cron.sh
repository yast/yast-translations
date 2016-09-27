#!/bin/bash
shopt -s nullglob

# Find out if we are in a directory containing a yast2 full checkout.
if [ ! -d "translations/.git" ]; then
    echo "Please run this script from a yast2 full checkout."
    exit 1
fi

WORKDIR=$PWD
TRANDIR=$WORKDIR/translations/po
TRANPARTS=$WORKDIR/translations/po-parts

# Check for the yast2-meta tool:
if ! Y2M=`command -v y2m`; then
    echo "The yast2-meta tool is required to run this script."
    echo "Find it here: https://github.com/yast/yast-meta"
    exit 1
fi

# Check for the yast2-buils tools:
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

function update_pot_headers {
    local INFILE=$1
    local OUTFILE=$2
    msgcat --use-first $INFILE -o $OUTFILE
}

function strip_POT_dates {
    local INFILE=$1
    local OUTFILE=$2
    sed '1,19{/^"PO.*ion-Date:/d}' <$INFILE >$OUTFILE
}

# main
# -------

# Pull all yast2 repositories:
$Y2M pull

# Clear the POT target directory
rm -rf $TRANPARTS

# Create POT files for (nerly) all subdirectories
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
    mkdir -p $TRANDIR/$DOMAIN

    # This is an ugly hack: Use the newest file as source of header
    NEWEST_POT=$(ls -1 -t $DOMAIN/*.pot)
    update_pot_headers $NEWEST_POT $TRANDIR/$DOMAIN/$DOMAIN.pot.new
    
    pushd $TRANDIR/$DOMAIN

    # Normalize POT line format
    msgcat $DOMAIN.pot -o $DOMAIN.pot.tmp
    strip_POT_dates $DOMAIN.pot.tmp $DOMAIN.pot.nodate
    strip_POT_dates $DOMAIN.pot.new $DOMAIN.pot.new.nodate

    if cmp -s $DOMAIN.pot.nodate $DOMAIN.pot.new.nodate; then
	echo "No changes in $DOMAIN.pot. Skipping update."
	rm *.tmp *.nodate *.new
	popd
	continue
    fi

    echo "Updating $DOMAIN."
    rm *.tmp *.nodate
    mv $DOMAIN.pot.new $DOMAIN.pot
    git add $DOMAIN.pot
    for PO in *.po ; do
	msgmerge --previous --lang=${PO%.po} $PO $DOMAIN.pot -o $PO.new 2>&1 > ${PO%.po}.log
	mv $PO.new $PO
	git add $PO
    done
    git commit -m "Automatic update of $DOMAIN."
    popd
done

echo "If no serious errors occured: git push"
