#!/bin/bash
#set -x

##
#Copyright 2013-2014, Franck Villaume - TrivialDev
#
# This file is part of TrivialDev Utilities.
#
# TrivialDev Utilities is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.

# TrivialDev Utilities is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with TrivialDev Utilities. If not, see <http://www.gnu.org/licenses/>.
##

function usage() {
	echo "$0 [-h|--help] [-v|--verbose] [-c|--clean] [-p|--path repository_path] [-r|--repo repository] [-l|--lock lockpath] [-n|--nometa]"
	echo " -h|--help    : print this help & exit."
	echo " -v|--verbose : print more informations."
	echo " -c|--clean   : remove lock file & exit."
	echo " -p|--path    : set path of the repositories. Default is /data/httpd/rhel6-x86_64. If you use another path, set correct path for rsync daemon."
	echo " -r|--repo    : regenerate repo for this repository only. Default is all repositories found in /data/httpd/rhel6-x86_64"
	echo " -l|--lock    : set lockpath. Default is /var/run. If you use another path, set correct path for rsync daemon."
	echo " -n|--nometa  : disable the use of metadata. Result: the yum list-security plugin will return empty."
	echo "example:"
	echo "  Regenerate the updates.dev repository"
	echo "  $0 -v -p /data/httpd/el6-x86_64 -r updates.dev"
}

SCRIPTNAME=`basename ${0}`
REPOPATH_BASE=/data/httpd/rhel6-x86_64/
LOCKFILEPATH_BASE=/var/run/
CLEAN=0
USEMETA=1
VERBOSE=0
REPOID=''
OPTS=$( getopt -o hcvp:r:ln -l help,clean,verbose,path:,repo:,lock,nometa -- "$@" )
if [[ $? != 0 ]]; then
	echo "Missing getopt or wrong arguments."
	usage
	exit 1
fi
eval set -- "$OPTS"
while true ; do
	case "$1" in
		-h|--help)
			usage
			exit 0
			;;
		-c|--clean)
			CLEAN=1
			shift 1
			;;
		-v|--verbose)
			VERBOSE=1
			shift 1
			;;
		-p|--path)
			REPOPATH_BASE=$2
			shift 2
			;;
		-r|--repo)
			REPOID=$2
			shift 2
			;;
		-l|--lock)
			LOCKFILEPATH_BASE=$2
			shift 2
			;;
		-n|--nometa)
			USEMETA=0
			shift 1
			;;
		--)
			shift
			break
			;;
	esac
done

if [[ ${VERBOSE} != 1 ]]; then
	exec 1>/dev/null
	exec 2>/dev/null
fi

if [[ ! -d ${LOCKFILEPATH_BASE}/rsync/rhn6 ]];then
	mkdir -p ${LOCKFILEPATH_BASE}/rsync/rhn6
fi

if [[ ${CLEAN} == 0 ]];then
	if [[ -f ${LOCKFILEPATH_BASE}/rsync/rhn6/rhel6.sh || -f ${LOCKFILEPATH_BASE}/${SCRIPTNAME} ]];then
		if [[ ${VERBOSE} != 0 ]];then
			echo "Already running or sync from rhn in action"
		fi
		exit 0
	fi

	LSUPDATESINFOXMLGZ=`ls ${REPOPATH_BASE}/updates.in/*updateinfo.xml.gz >/dev/null 2>&1`
	if [[ ${USEMETA} != 0 && -z ${LSUPDATESINFOXMLGZ} ]];then
		if [[ ${VERBOSE} != 0 ]];then
			echo "Missing metadata."
		fi
		exit 0
	fi
	
	CREATEREPOVERSION=`createrepo --version | cut -f2 -d' '`
	case "${CREATEREPOVERSION}" in
		0.9.8)
			CREATEREPOOPTION=''
			;;
		*)
			CREATEREPOOPTION='--no-database'
			;;
	esac

	touch ${LOCKFILEPATH_BASE}/${SCRIPTNAME}

	if [[ 'z'${REPOID} == 'z' ]];then
		REPOID=`ls -1 ${REPOPATH_BASE}`
	fi
	
	if [[ ${USEMETA} != 0 ]];then
		for each in ${REPOID}; do
			if [[ ${each} != 'os' && ${each} != 'tierces' ]]; then
				cp ${REPOPATH_BASE}/metadata.in/*updateinfo.xml.gz ${REPOPATH_BASE}/${each}/
			fi
		done
	fi

	for repo in ${REPOID}; do
		if [[ ${repo} != 'os' ]]; then
			if [[ ${VERBOSE} != 0 ]];then
				echo "Generate repository for "${repo}
			fi
			cd ${REPOPATH_BASE}/${repo}
			rm -rf repodata
			createrepo ${CREATEREPOOPTION} .
			if [[ ${USEMETA} != 0 ]];then
				if [[ ${VERBOSE} != 0 ]];then
					echo "Adding metadata in repository "${repo}
				fi
				echo '<?xml version="1.0" encoding="UTF-8"?>' >updateinfo.xml
				echo '<updates>' >> updateinfo.xml
				for updatefile in `ls -1tr |grep updateinfo.xml.gz`; do
					gunzip -f ${updatefile}
					sed -i -e 's|<updates>||' -e 's|</updates>||' -e '/xml version="1.0" encoding="UTF-8"/d' ${updatefile%.gz}
					cat ${updatefile%.gz} >> updateinfo.xml
					rm ${updatefile%.gz}
				done
				echo '</updates>' >> updateinfo.xml
				modifyrepo updateinfo.xml repodata
				rm updateinfo.xml
			fi
		else
			if [[ ${VERBOSE} != 0 ]];then
				echo "Repository os skipped"
			fi
		fi
	done

	for each in `ls -1 ${REPOPATH_BASE}`; do
		if [[ ${each} != 'os' && ${each} != 'updates.in' && ${each} != 'tierces' ]]; then
			rm -f ${REPOPATH_BASE}/${each}/*updateinfo.xml.gz
		fi
	done
	rm -f ${REPOPATH_BASE}/metadata.in/*updateinfo.xml.gz
fi
rm -f ${LOCKFILEPATH_BASE}/${SCRIPTNAME}
exit 0