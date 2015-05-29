#!/bin/bash

#region Default Variables

    default_version=11.4.4
    default_env=_default
    default_username=${USER}
    default_runlist="role[base]"
    default_distro='chef-full'

#endregion Default Variables

#region Help

function usage () {
usageMessage="
-----------------------------------------------------------------------------------------------------------------------
AUTHOR:       Levon Becker
PURPOSE:      Deploy Chef Client on a Remote System
VERSION:      1.2.0
WIKI:         http://www.bonusbits.com/main/Automation:Deploy_ChefClient.sh
DESCRIPTION:  This script is used to install Chef client on a remote host via SSH. Run this script on a workstation
              that is setup with knife and has the validator.pem.
-----------------------------------------------------------------------------------------------------------------------
|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-----------------------------------------------------------------------------------------------------------------------
PARAMETERS
-----------------------------------------------------------------------------------------------------------------------
-v Chef Client version to install. The default is ($default_version)
-n Node, FQDN of the remote host to deploy chef client to.
-e Environment to add the node to. The default is ($default_env)
-u SSH Username to us while connecting to the remote node. The default is ($default_username)
-r Run List. The default is ($runlist). For multiple runlists comma seperate them.
-a DNS Alias name to use as the client node name instead of the actual hostname.
-d Bootstrap Distro Template in the working directorys /bootstrap subfolder.
    The default is ($default_distro)
        Search order:
        1. Subfolder in working directory bootstrap/
        2. Chef-Repo named bootstrap/
        3. ~/.chef/bootstrap/

-----------------------------------------------------------------------------------------------------------------------
EXAMPLES
-----------------------------------------------------------------------------------------------------------------------
$0 -v 11.4.4 -n server01.domain.com -e apache-dev -u username


$0 -n "server01.domain.com" -e "apache-dev" -u "username" -a "apache-dev01" -r "'role[web-server]'"
$0 -n "server01.domain.com" -e "apache-dev" -u "username" -a "apache-dev01" -r "'role[base]','role[web-server]'"

-----------------------------------------------------------------------------------------------------------------------
"
    echo "$usageMessage";
}

#endregion Help

#region Arguments

    while getopts "v:n:e:u:r:a:d:h" opts; do
        case $opts in
            v ) version=$OPTARG;;
            n ) nodename=$OPTARG;;
            e ) env=$OPTARG;;
            u ) username=$OPTARG;;
            r ) runlist=$OPTARG;;
            a ) aliasname=$OPTARG;;
            d ) distro=$OPTARG;;
            h ) usage; exit 0;;
            * ) usage; exit 1;;
        esac
    done

    # Use defaults if missing arguments
    if [ -z $version ]; then version=$default_version; fi
    if [ -z $env ]; then env=$default_env; fi
    if [ -z $username ]; then username=$default_username; fi
    if [ -z $runlist ]; then runlist=$default_runlist; fi
    if [ -z $distro ]; then distro=$default_distro; fi
    if [ -z $nodename ]
    then
        logMe "Script file argument required - aborting";
        usage;
        exit 1;
    fi

    # If Node Name null then don't pass --node-name nil
    if [ $aliasname ]; then alias_command="--node-name ${aliasname}"; fi

#endregion Arguments

#region Prerequisites

    echo "Checking Prerequisites..."
    ecount=0

    if [ ! -d ~/.chef ]
    then
        echo "ERROR - Directory not found: ~/.chef"
        ecount=$(($ecount+1))
    else
        if [ ! -f ~/.chef/knife.rb ]
        then
            echo "ERROR - File not found: ~/.chef/bootstrap/$distro.erb"
            ecount=$(($ecount+1))
        else
            edbsline=`grep ^encrypted_data_bag_secret ~/.chef/knife.rb`
            if [ $? -ne 0 ]
            then
                echo "ERROR - Setting not found: encrypted_data_bag_secret in ~/.chef/knife.rb"
                ecount=$(($ecount+1))
            else
                read -a edbsarray <<< "$edbsline"
                edbspath=${edbsarray[1]}
                edbspath=${edbspath%\"}
                edbspath=${edbspath#\"}
                eval edbspath=$edbspath
                if [ ! -f $edbspath ]
                then
                    echo "ERROR - File not found: $edbspath"
                    ecount=$(($ecount+1))
                fi
            fi
        fi

        if [ ! -d ~/.chef/bootstrap ]
        then
            echo "ERROR - Directory not found: ~/.chef/bootstrap"
            ecount=$(($ecount+1))
        else
            if [ ! -f ~/.chef/bootstrap/$distro.erb ]
            then
                echo "ERROR - File not found: ~/.chef/bootstrap/$distro.erb"
                ecount=$(($ecount+1))
            fi
        fi
    fi

    if [ $ecount -eq 0 ]
    then
        echo "Prerequisites satisfied"
    else
        echo "Prerequisites not satisfied"
        echo "Aborting"
        exit 1
    fi

#endregion Prerequisites

#region Tasks

    # Deploy Chef Client to Remote Host
    knife bootstrap $nodename --bootstrap-version $version --ssh-user $username --sudo --run-list $runlist --environment $env --distro $distro $alias_command

#endregion Tasks