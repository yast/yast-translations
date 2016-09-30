#!/bin/bash

set -o errexit

function weblate_django_shell() {
	if test -z "$(which weblate-ssh)" ; then
		echo "This command needs ssh access to l10n.opensuse.org server." >&2
		echo "Please install/create weblate-ssh script wrapper." >&2
		echo "It is not part of this repository because it contains sensitive data." >&2
		exit 1
	fi
	# For debugging, uncomment cat and comment out weblate-ssh
	#cat
	weblate-ssh 'su -l -s /usr/bin/python wwwrun /usr/share/weblate/manage.py shell'
}

# Warning: weblate_manage() does not escape arguments. Do not use spaces!
function weblate_manage() {
	if test -z "$(which weblate-ssh)" ; then
		echo "This command needs ssh access to l10n.opensuse.org server." >&2
		echo "Please install/create weblate-ssh script wrapper." >&2
		echo "It is not part of this repository because it contains sensitive data." >&2
		exit 1
	fi
	# For debugging, uncomment cat and comment out weblate-ssh
	#cat
	weblate-ssh "su wwwrun -s /bin/sh -c '/usr/bin/python /usr/share/weblate/manage.py $*'"
}

# weblate_create_project yast_textdomain yast_project
function weblate_create_project() {
	local NAME=yast-$1
	# special handling for textdomains starting by "yast2-"
	if test "${NAME#yast-yast2-}" != "$NAME" ; then
		NAME="yast-${NAME#yast-yast2-}"
	fi
	local SLUG="$(echo $NAME | tr A-Z. a-z-)"
	if test -n "$(echo $SLUG | sed 's/[-a-z0-9_]//g')" ; then
		echo "Project URL slug \"$SLUG\" should contain only lowercase letters, \"-\" and \"_\"." >&2
		echo "Please fix or add a name convertor." >&2
		exit 1
	fi
	local WEB_FOUND=false
	for WEB_PART in yast/yast-$2 yast/$2 libyui/yast-$2 libyui/$2 ; do
		WEB=https://github.com/$WEB_PART
		if curl -f -I $WEB >/dev/null 2>&1 ; then
			WEB_FOUND=true
			break
		fi
	done
	if ! $WEB_FOUND ; then
		echo "Project web not found." >&2
		echo "Please add a web lookup." >&2
		exit 1
	fi

# Not yet implemented in Weblate API.
#	curl \
#		-H "Authorization: Token $(<.weblate-api-key)" \
#		-T- \
#		http://l10n.opensuse.org/api/projects/$NAME <<EOF
#	{
#		"name":"$NAME",
#		"slug":"$SLUG",
#		"web":"$WEB",
#		"push_on_commit":"true",
#	}
#EOF
	weblate_django_shell <<EOF
from weblate.trans.models.project import Project
project = Project(name="$NAME",slug="$SLUG",web="$WEB",push_on_commit=True)
project.save()
EOF
}

# weblate_create_project yast_textdomain yast_project yast_branch
function weblate_create_component() {
	local PROJECT_NAME=yast-$1
	# special handling for textdomains starting by "yast2-"
	if test "${PROJECT_NAME#yast-yast2-}" != "$PROJECT_NAME" ; then
		PROJECT_NAME="yast-${PROJECT_NAME#yast-yast2-}"
	fi
	local PROJECT_SLUG="$(echo $PROJECT_NAME | tr A-Z. a-z-)"
	if test -n "$(echo $PROJECT_SLUG | sed 's/[-a-z0-9_]//g')" ; then
		echo "Project URL slug \"$PROJECT_SLUG\" should contain only lowercase letters, \"-\" and \"_\"." >&2
		echo "Please fix or add a name convertor." >&2
		exit 1
	fi
	local SLUG="$(echo $3 | tr A-Z. a-z-)"
	if test -n "$(echo $SLUG | sed 's/[-a-z0-9_]//g')" ; then
		echo "Component URL slug \"$SLUG\" should contain only lowercase letters, \"-\" and \"_\"." >&2
		echo "Please fix or add a name convertor." >&2
		exit 1
	fi
	local WEB_FOUND=false
	for WEB_PART in yast/yast-$2 yast/$2 libyui/yast-$2 libyui/$2 ; do
		WEB=https://github.com/$WEB_PART
		if curl -f -I $WEB >/dev/null 2>&1 ; then
			WEB_FOUND=true
			break
		fi
	done
	if ! $WEB_FOUND ; then
		echo "Project web not found." >&2
		echo "Please add a web lookup." >&2
		exit 1
	fi
	local BRANCH_FOUND=false
	if curl -f -I $WEB/tree/$3 >/dev/null 2>&1 ; then
		BRANCH_FOUND=true
	fi
	if ! $BRANCH_FOUND ; then
		echo "Project branch not found." >&2
		echo "Please fix." >&2
		exit 1
	fi
	# yast-base is the core repository for checkouts. All other repos will use Weblate internal URLs
	# FIXME: Can it reuse different branch? If yes, it should be:
	# if test "$1" = "base" -a "$3" = "master" ; then
	#	REPO=weblate://yast-base/master
	if test "$1" = "base" ; then
		REPO=git@github.com:yast/yast-translations.git
		PUSH=",push=\"$REPO\""
	else
		REPO=weblate://yast-base/$SLUG
		PUSH=
	fi
	weblate_django_shell <<EOF
from weblate.trans.models.project import Project
from weblate.trans.models.subproject import SubProject
project = Project.objects.get(name="$PROJECT_NAME")
component = SubProject(name="$3",slug="$SLUG",project=project,vcs="git",repo="$REPO"$PUSH,repoweb="https://github.com/$WEB_PART/blob/%(branch)s/%(file)s#L%(line)s",branch="$3",filemask="po/$1/*.po",new_base="po/$1/$1.pot",file_format="po",new_lang="add")
component.save()
EOF
}

# weblate_upload_suggestion project component language file
function weblate_upload_suggestions() {
	cat $4 | weblate-ssh cat \>/tmp/weblate-upload-file.po
	weblate_manage add_suggestions --author=weblate-admin@opensuse.org $1 $2 $3 /tmp/weblate-upload-file.po
	weblate-ssh rm /tmp/weblate-upload-file.po
}

## This code is saved for use of Weblate API.
## API is incomplete and it can be used only for some tasks.
#
#if ! test -f ".weblate-api-key" ; then
#	echo "Please save Weblate admin API token from https://l10n.opensuse.org/accounts/profile/#api as .weblate-api-key" >&2
#	exit 1
#fi
#
#YAST_PROJECT_LIST=$(
#	cd ../po
#	for DIR in * ; do
#		if test -d "$DIR" ; then
#			echo $DIR
#		fi
#	done
#)
#
#WEBLATE_PROJECT_LIST=$(
#	curl \
#		-H "Authorization: Token $(<.weblate-api-key)" \
#		http://l10n.opensuse.org/api/projects/ |
#	json_pp -f json -t json |
#	sed -n 's/"//g;s/,//g;s/slug[[:space:]]*://p'
#)
#
#curl \
#    -H "Authorization: Token $(<.weblate-api-key)" \
#    "https://l10n.opensuse.org/api/translations/libgettextdemo/master/cs/file/?format=po" \
#    >file.po
#
## Works, but suggestions and other fine features are not yet implemented.
##Warning: skip unknown form field: method=suggest
#curl \
#    -H "Authorization: Token $(<.weblate-api-key)" \
#    -F "file=@file.po;method=suggest" \
#    "https://l10n.opensuse.org/api/translations/libgettextdemo/master/cs/file/"
