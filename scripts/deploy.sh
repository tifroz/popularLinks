#!/bin/sh
#

source ~/.profile
source ./env.sh

#################################################################################################
#	1. Create a new meteor project dir on the remote host and copy src to the new project
#	2. Bundle the project on the remot host and expand into the bundle directory for execution
##################################################################################################


#REMOTE_ROOT="/opt/monitor"
#LOCAL_ROOT="/Users/hugo/Projects/monitor/server"
#TIMESTAMP=$(date +"%m-%d-%Y_%khr%Mmin%S")

if [ $# -gt 0 ]; then
	REMOTE_HOST="$1"
else
	REMOTE_HOST="dev.swishly.com"
fi


echo ">> Copying source & config files" | growlnotify -t "$REMOTE_HOST deploy"
rsync -axSzv --copy-links --delete\
	--include="/package.json" \
	--include="/dist/" \
	--exclude=".*" \
	--exclude="/*" \
	"$LOCAL_ROOT/" "$REMOTE_HOST:$REMOTE_ROOT/"


echo ">> Installing npm modules" | growlnotify -t "$REMOTE_HOST deploy"
npmCmd="cd $REMOTE_ROOT/; npm install"
ssh -t -t $REMOTE_HOST "$npmCmd"


echo ">> Reached end of built script" | growlnotify -t "$REMOTE_HOST deploy"



