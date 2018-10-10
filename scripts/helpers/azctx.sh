#!/bin/sh
# should only depend on az, jq, ~busybox (so potentially usable in alpine?)

# random-access "git stash" for `$AZURE_CONFIG_DIR` (~/.azure) dirs
#
# Let's you swap between various rp and user logins, and/or various default subs
#
# keeps core configuration in place throughout (this stuff: format, telemetry, etc:
#  https://docs.microsoft.com/en-us/cli/azure/azure-cli-configuration#cli-configuration-values-and-environment-variables
# ); though that could be changed to go along for the ride.
#
# !!! RESTORE/POP IS A DESTRUCTIVE OPERATION !!!
#
# the $AZURE_CONFIG_DIR (~/.azure) most recently switched to is "checked out"
# and removed from the saved collection; this is intended to avoid
# a ~infinite build up that is likely to otherwise occur.
#
# thus it is prudent to run an explicit `azctx save` before `az login`
# or `az account set` if you want to be able to return to the before-state
#
# e.g.
#
# azctx save dev
# az account set -s 50741593-1a32-43cc-9126-e338c6de58a7
# azctx save westus2
#
# azctx -f dev
#   -> dev will be current, but no longer be saved
#      until you save again
#
# ( or unless you saved twice not in the same minute
# ... or at whatever granularity $AZCTX_DATE_FORMAT allows for, with how you have it set)


# this script forgoes
# set -eu
# because it should support `source`ing & we shouldn't force that on the sourcing context

AZURE_CONFIG_DIR=${AZURE_CONFIG_DIR:-$HOME/.azure}

AZCTX_DIR=${AZCTX_DIR:-${AZURE_CONFIG_DIR}.saved}
AZCTX_SAVE_ON_SWITCH=${AZCTX_SAVE_ON_SWITCH:-1}

AZCTX_DATE_FORMAT=${AZCTX_DATE_FORMAT:-'%Y-%m-%d_%H%M'}
function _azctx_date {
    date -u +$AZCTX_DATE_FORMAT
}

# In order to support any $AZURE_CONFIG_DIR
# and cause I'm not sure it actually works in dash/ash/sh
#
# I forwent using ~ expansion in this script
#
# but its a nice thing to have for output, so I mask it back in
# ~ @donald
function _azctx_echo {
    echo $@ | sed "s|$HOME|~|g"
}

function _azctx__save {
    ctxdir=$1
    date=$2

    mkdir -p ${ctxdir}
    cp $AZURE_CONFIG_DIR/config ${AZCTX_DIR}/.last_config

    rm -rf ${ctxdir}/${date}
    mv $AZURE_CONFIG_DIR ${ctxdir}/${date}

    rm -f ${ctxdir}/latest
    ln -s ${ctxdir}/${date} ${ctxdir}/latest
}

function _azctx_save {
    name=$1
    date=`_azctx_date`

    _azctx_echo "Saving current $AZURE_CONFIG_DIR to ${AZCTX_DIR}/${name}/$date"

    _azctx__save "${AZCTX_DIR}/${name}" $date
}

function _azctx__restore {
    source=$1

    rm -rf $AZURE_CONFIG_DIR
    mv $source $AZURE_CONFIG_DIR
    cp $AZCTX_DIR/.last_config $AZURE_CONFIG_DIR/config

    namedir=`dirname $source`

    # delete the parent dir if its empty now
    rm -f $namedir/latest
    rmdir $namedir > /dev/null 2> /dev/null

    # if the dir still exists, correct the latest pointer
    if [ -d $namedir ]; then
        latest=`(cd $namedir && ls -1 | sort -n | tail -1)`
        ln -s $namedir/$latest $namedir/latest
    fi
}

function _azctx_restore {
    name=$1
    date=${2:-latest}

    if [ ! -d ${AZCTX_DIR}/${name} ]; then
        echo "ERROR: Unknown target: ${name}" >&2
        return 1
    fi

    # canonicalize latest to its real dir
    if [ "$date" = "latest" ]; then
        datedir=`cd ${AZCTX_DIR}/${name}/latest && pwd -P`
        date=`basename $datedir`
    fi

    _azctx_echo "Restoring ${AZCTX_DIR}/${name}/$date to $AZURE_CONFIG_DIR"

    _azctx__restore "${AZCTX_DIR}/${name}/$date"
}

function _azctx_current_name {
    az_account_show=`az account show -o json 2> /dev/null`
    if [ $? -ne 0 ]; then
        return 1
    fi

    AZ_USER_TYPE=`echo "$az_account_show" | jq -j '.user.type'`
    AZ_USER_NAME=`echo "$az_account_show" | jq -j '.user.name'`

    if [ "$AZ_USER_TYPE" = "user" ]; then
        printf "$AZ_USER_NAME"
    elif [ "$AZ_USER_TYPE" = "servicePrincipal" ]; then
        (az ad sp show --id $AZ_USER_NAME -o json | jq -j '.displayName') || printf "sp-$AZ_USER_NAME"
    else
        printf "UNKOWN-"`uuidgen`
    fi
}

function azctx {
    target=$1

    local save_on_switch
    save_on_switch=$AZCTX_SAVE_ON_SWITCH

    if [ -z "$1" ]; then
      target="help"
    fi

    case $target in
    -f|--drop-current)
        save_on_switch=0
        shift
        target=$1
        ;;
    save)
        # explicit save should be nondestructive
        cp -R $AZURE_CONFIG_DIR $AZURE_CONFIG_DIR.saving || return 1

        name=${2:-`_azctx_current_name`}
        _azctx_save $name
        mv $AZURE_CONFIG_DIR.saving $AZURE_CONFIG_DIR
        return
        ;;
    list)
        list_target=${2:-}
        if [ -z "`ls $AZCTX_DIR`" ]; then
            echo "No saved contexts" >&2
            return
        elif [ ! -d $AZCTX_DIR/$list_target ]; then
            echo "No saved contexts maching '$list_target'" >&2
            return
        fi
        (cd $AZCTX_DIR/$list_target && ls -d1 *)
        return
        ;;
    help|-h|-help|--help)
      _azctx_echo "azctx - random-access \"git stash\" for your $AZURE_CONFIG_DIR directory"
      echo
      echo "Usage: azctx list [<name>]"
      echo "       azctx save [<name>]"
      echo "       azctx [-f | --drop-current] <name> [<date>]"
      echo
      echo "  list             - lists the saved contexts"
      echo "  save <name>      - save the current context as <name>"
      echo "  <name>           - pop the latest instance of <name>, saving current (if any) w/ automatic name"
      echo "  -f <name>        - pop the latest instance of <name>, discarding current context"
      echo
      echo "  save             - save the current context using automatically determined (user or sp) name"
      echo "  list <name>      - list the date-instances for the given name"
      echo "  <name> <date>    - pop the <date> instance of <name>, saving current (if any) w/ automatic name"
      echo "  -f <name> <date> - pop the <date> instance of <name>, discarding current context"

      return
      ;;
    esac

    if [ "$save_on_switch" -ne 0 ]; then
        name=`_azctx_current_name`
        if [ $? -eq 0 ]; then
            _azctx_save $name
        fi

        # this should only be the case if save failed or an az login ran simultaneously
        # if we are in -f mode we assume we don't care tho
        if test -f $AZURE_CONFIG_DIR/accessTokens.json; then
            _azctx_echo "ERROR: $AZURE_CONFIG_DIR/accessTokens.json exists" >&2
            echo 'Refusing to clobber' >&2
            return
        fi
    fi

    _azctx_restore $target ${2:-}
}

#TODO: tab completions: azctx <tab> -> azctx list