#!/bin/bash
#set -x

##
#Copyright 2013-2015, Franck Villaume - TrivialDev
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

##
# This script allows you to sync data from an existing repoid to a local copy (on the same server or a distant server)
# RHEL5, RHEL6 & RHEL7 supported
# With this script you can use Spacewalk server at an alternative to RedHat Official Satellite.
##

function usage() {
	echo "$0 [-h|--help] [-v|--verbose] [-c|--clean] [-p|--path repository_path] [-r|--repo repository] [-l|--lock lockpath] [-n|--nometa] [-i|--iprsync ip_address] [-t|--target distribution]"
	echo " -h|--help    : print this help & exit."
	echo " -v|--verbose : print more informations."
	echo " -c|--clean   : remove lock file & exit."
	echo " -p|--path    : set path of the repositories. Default is /data/rhn."
	echo " -r|--repo    : sync this rhn channel only."
	echo " -l|--lock    : set lockpath. Default is /var/run. If you use another path, set correct path for rsync daemon."
	echo " -n|--nometa  : disable the retrieve of metadata. Result: the yum list-security plugin will return empty."
	echo " -i|--iprsync : use this IP address / Hostname as rsync destination. Optional. By default, the sync stays locally."
	echo " -t|--target  : select the distribution you target. i.e. RHEL5, RHEL6, RHEL7. RHEL6 is the default"
	echo "example:"
	echo "  Sync the channel rhel-x86_64-server-6 only and rsync to another server."
	echo "  $0 -v -r rhel-x86_64-server-6 -i distantserver.fqdn"
}

#Default values for global vars
SCRIPTNAME=`basename ${0}`
LOCKFILEPATH_BASE=/var/run/
REPOSYNC_PATH=/data/rhn
RSYNC_DESTIP=
USEMETA=1
VERBOSE=0
CLEAN=0
DIST_TARGET='RHEL6'

OPTS=$( getopt -o hcvp:r:li:t:n -l help,clean,verbose,path:,repo:,lock,iprsync:,target:,nometa -- "$@" )
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
			REPOSYNC_PATH=$2
			shift 2
			;;
		-r|--repo)
			REPOSYNC_REPOID=$2
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
		-i|--iprsync)
			RSYNC_DESTIP=$2'::'
			shift 2
			;;
		-t|--target)
			DIST_TARGET=$2
			shift 2
			;;
		--)
			shift
			break
			;;
	esac
done

if [[ ${VERBOSE} != 1 ]];then
	exec 1>/dev/null
	exec 2>/dev/null
fi

case ${DIST_TARGET} in
	RHEL5)
		REPOSYNC_REPOID="rhel-x86_64-server-5"
		RSYNC_DESTPATH_PACKAGES=/data/httpd/rhel5-x86_64/updates.in/Packages
		RSYNC_DESTPATH_META=/data/httpd/rhel5-x86_64/metadata.in
		RSYNC_DESTPATH_LOCK=${LOCKFILEPATH_BASE}/rsync/rhn5
		USEGETPACKAGE='/getPackages'
		LOCKFILENAME='rhel5.sh'
		YUMCACHE_PATH='/var/cache/yum'
		if [[ ! -z ${RSYNC_DESTIP} ]];then
			RSYNC_DESTPATH_PACKAGES=rhel5-updatein
			RSYNC_DESTPATH_META=rhel5-metadatain
			RSYNC_DESTPATH_LOCK=rhnlock5
		fi
		;;
	RHEL7)
		REPOSYNC_REPOID="rhel-7-server-rpms"
		RSYNC_DESTPATH_PACKAGES=/data/httpd/rhel7-x86_64/updates.in/Packages
		RSYNC_DESTPATH_META=/data/httpd/rhel7-x86_64/metadata.in
		RSYNC_DESTPATH_LOCK=${LOCKFILEPATH_BASE}/rsync/rhn7
		USEGETPACKAGE='/Packages'
		LOCKFILENAME='rhel7.sh'
		YUMCACHE_PATH='/var/cache/yum/x86_64/7Server'
		if [[ ! -z ${RSYNC_DESTIP} ]];then
			RSYNC_DESTPATH_PACKAGES=rhel7-updatein
			RSYNC_DESTPATH_META=rhel7-metadatain
			RSYNC_DESTPATH_LOCK=rhnlock7
		fi
		;;
	RHEL6|*)
		#REPOSYNC_REPOID="rhel-x86_64-server-6 rhel-x86_64-server-supplementary-6 rhel-x86_64-server-optional-6 rhel-x86_64-server-ha-6"
		REPOSYNC_REPOID="rhel-x86_64-server-6"
		RSYNC_DESTPATH_PACKAGES=/data/httpd/rhel6-x86_64/updates.in/Packages
		RSYNC_DESTPATH_META=/data/httpd/rhel6-x86_64/metadata.in
		RSYNC_DESTPATH_LOCK=${LOCKFILEPATH_BASE}/rsync/rhn6
		USEGETPACKAGE='/getPackages'
		LOCKFILENAME='rhel6.sh'
		YUMCACHE_PATH='/var/cache/yum/x86_64/6Server'
		if [[ ! -z ${RSYNC_DESTIP} ]];then
			RSYNC_DESTPATH_PACKAGES=rhel6-updatein
			RSYNC_DESTPATH_META=rhel6-metadatain
			RSYNC_DESTPATH_LOCK=rhnlock6
		fi
		;;
esac

if [[ ! -d ${RSYNC_DESTPATH_LOCK} ]];then
	mkdir -p ${RSYNC_DESTPATH_LOCK}
fi

if [[ -z ${RSYNC_DESTIP} ]];then
	mkdir -p ${RSYNC_DESTPATH_PACKAGES}
	mkdir -p ${RSYNC_DESTPATH_META}
fi

if [[ ! -f /etc/yum/pluginconf.d/rhnplugin.conf.enable && ! -f /etc/yum/pluginconf.d/rhnplugin.conf.enable ]];then
	cd /etc/yum/pluginconf.d
	cat << EOF >rhnplugin.conf.enable
[main]
enabled=1
gpgcheck=1
EOF
	cat << EOF >rhnplugin.conf.disable
[main]
enabled=0
gpgcheck=1
EOF
	rm -f rhnplugin.conf
	ln -s rhnplugin.conf.enable rhnplugin.conf
	cd - >/dev/null 2>&1
fi

if [[ ${CLEAN} == 0 ]];then
	if [[ -f ${LOCKFILEPATH_BASE}/${SCRIPTNAME} ]];then
		if [[ ${VERBOSE} != 0 ]];then
			echo "Already sync from rhn in action"
		fi
		exit 0
	fi

	touch ${LOCKFILEPATH_BASE}/${SCRIPTNAME}
	touch ${RSYNC_DESTPATH_LOCK}/${LOCKFILENAME}
	rsync -az --force --ignore-errors --delete ${RSYNC_DESTPATH_LOCK} ${RSYNC_DESTIP}${RSYNC_DESTPATH_LOCK}
	rm -f /etc/yum/pluginconf.d/rhnplugin.conf
	cd /etc/yum/pluginconf.d
	ln -s rhnplugin.conf.enable rhnplugin.conf
	cd - >/dev/null 2>&1

	for each in ${REPOSYNC_REPOID}; do
		if [[ ${VERBOSE} != 0 ]];then
			echo "Sync rpms for channel "${each}
		fi
		mkdir -p ${REPOSYNC_PATH}/${each}${USEGETPACKAGE}
		reposync ${REPOMETAOPTION} -p ${REPOSYNC_PATH} --repoid=${each} -a x86_64 -l
		reposync -p ${REPOSYNC_PATH} --repoid=${each} -a i686 -l
		rsync -az --force --progress --ignore-errors ${REPOSYNC_PATH}/${each}${USEGETPACKAGE}/ ${RSYNC_DESTIP}${RSYNC_DESTPATH_PACKAGES}
		if [[ ${USEMETA} != 0 ]];then
			yum --disablerepo="*" --enablerepo="${each}" clean all
			yum --disablerepo="*" --enablerepo="${each}" makecache
			if [[ ${VERBOSE} != 0 ]];then
				echo "Sync metadata for channel "${each}
			fi
			for updatefile in `ls -1 ${YUMCACHE_PATH}/$each/ |grep 'updateinfo.xml.gz'`; do
				rsync -az --force --progress --ignore-errors ${YUMCACHE_PATH}/$each/${updatefile} ${RSYNC_DESTIP}${RSYNC_DESTPATH_META}
				rm -f ${YUMCACHE_PATH}/$each/${updatefile}
			done
		fi
	done
	rm -f /etc/yum/pluginconf.d/rhnplugin.conf
	cd /etc/yum/pluginconf.d
	ln -s rhnplugin.conf.disable rhnplugin.conf
	cd - >/dev/null 2>&1
fi

if [[ ${VERBOSE} != 0 ]];then
	echo "Remove lock files"
fi
rm -f ${RSYNC_DESTPATH_LOCK}/${LOCKFILENAME}
if [[ ! -z ${RSYNC_DESTIP} ]]; then
	rsync -za ${QUIET} --force --ignore-errors --delete ${RSYNC_DESTPATH_LOCK} ${RSYNC_DESTIP}${RSYNC_DESTPATH_LOCK}
fi
rm -f ${LOCKFILEPATH_BASE}/${SCRIPTNAME}

exit 0
