#!/bin/sh


source ./env.sh

pids=""

#watchman "$ROOT/src/popularLinksHelper/package.json" "cp '<%= @file %>' '$DIST_ROOT/popularLinksHelper/package.json'" 2>&1 | tee -a "$BUILDLOGFILE" &
#pids="$pids $!"

coffee -wcbo "$ROOT/dist" "$ROOT/src"  2>&1 | tee -a "$BUILDLOGFILE" &
pids="$pids $!"

coffee -wcbo "$ROOT/dist/node_modules" "$ROOT/src_modules"  2>&1 | tee -a "$BUILDLOGFILE" &
pids="$pids $!"

coffee -wcbo "$ROOT/dist/node_modules" "$ROOT/src_modules"  2>&1 | tee -a "$BUILDLOGFILE" &
pids="$pids $!"

trap 'echo Killing the coffee compilers $pids; kill $pids; pkill -P $$ tail ;exit 0' SIGINT SIGHUP SIGTERM SIGQUIT


tail -n0 -F "$BUILDLOGFILE" | while read; do
		echo $REPLY
    csmsg=$(echo "$REPLY" | egrep "^In.*")
    #echo "$msg" 
    if [ -n "$csmsg" ]; then
			file=$(echo "$REPLY" | egrep -o "\w*.coffee")
			line=$(echo "$REPLY" | egrep -o "line [0-9]*")
			message=$(echo "$REPLY" | egrep -o "[\:|,].*")
			growlnotify -s -t "$file $line" --html -m "$message"  --image "/Users/hugo/Library/Growl/PNG/Error.png" --identifier "error_line"
    fi
		btmsg=$(echo "$REPLY" | egrep "Compiled")
		if [ -n "$btmsg" ]; then
			growlnotify -t "Auto-build" --html -m "$btmsg" --image "/Users/hugo/Library/Growl/PNG/Status.png"
		fi
		errmsg=$(echo "$REPLY" | egrep -i "error|fail")
		if [ -n "$errmsg" ]; then
			growlnotify -s -t "Auto-build Error" -s -m "$errmsg" --image "/Users/hugo/Library/Growl/PNG/Error.png"
		fi
done




