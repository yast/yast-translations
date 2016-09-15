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

# weblate_create_project yast_textdomain yast_project
function weblate_create_project() {
	local SLUG="$(echo $1 | tr A-Z. a-z-)"
	if test -n "$(echo $SLUG | sed 's/[-a-z_]//g')" ; then
		echo "Project URL slug \"$SLUG\" should contain only lowercase letters, \"-\" and \"_\"." >&2
		echo "Please fix or add a name convertor." >&2
		exit 1
	fi
	local WEB_FOUND=false
	for WEB_PART in yast-$2 $2 ; do
		WEB=https://github.com/yast/$WEB_PART
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
#		http://l10n.opensuse.org/api/projects/yast-$1 <<EOF
#	{
#		"name":"yast-$1",
#		"slug":"yast-$1",
#		"web":"$WEB",
#		"push_on_commit":"true",
#	}
#EOF
	weblate_django_shell <<EOF
from weblate.trans.models.project import Project
project = Project(name="yast-$1",slug="yast-$SLUG",web="$WEB",push_on_commit=True)
project.save()
EOF
}

# weblate_create_project yast_textdomain yast_project yast_branch
function weblate_create_component() {
	local PROJECT_SLUG="$(echo $1 | tr A-Z. a-z-)"
	if test -n "$(echo $PROJECT_SLUG | sed 's/[-a-z_]//g')" ; then
		echo "Project URL slug \"$PROJECT_SLUG\" should contain only lowercase letters, \"-\" and \"_\"." >&2
		echo "Please fix or add a name convertor." >&2
		exit 1
	fi
	local SLUG="$(echo $3 | tr A-Z. a-z-)"
	if test -n "$(echo $SLUG | sed 's/[-a-z_]//g')" ; then
		echo "Component URL slug \"$SLUG\" should contain only lowercase letters, \"-\" and \"_\"." >&2
		echo "Please fix or add a name convertor." >&2
		exit 1
	fi
	local WEB_FOUND=false
	for WEB_PART in yast-$2 $2 ; do
		WEB=https://github.com/yast/$WEB_PART
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
	else
		REPO=weblate://yast-base/$SLUG
	fi
	weblate_django_shell <<EOF
from weblate.trans.models.project import Project
from weblate.trans.models.subproject import SubProject
project = Project.objects.get(name="yast-$1")
component = SubProject(name="$3",slug="$SLUG",project=project,vcs="git",repo="$REPO",push="$REPO",repoweb="https://github.com/yast/$WEB_PART/blob/%(branch)s/%(file)s#L%(line)s",branch="$3",filemask="po/$1/*.po",new_base="po/$1/$1.pot",file_format="po",new_lang="add")
component.save()
EOF
}
