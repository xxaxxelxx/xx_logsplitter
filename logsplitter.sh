#!/bin/bash
DEPOTDIR="/depot"
SPLITBASEDIR="/customer"
if [ "x$DEPOTDIR" == "x" ]; then exit; fi

MAXAGE=366

SLEEP=60

test -d $SPLITBASEDIR || mkdir -p $SPLITBASEDIR

for CUSTOMER in $@; do
    test -d $SPLITBASEDIR/$CUSTOMER/logs || mkdir -p $SPLITBASEDIR/$CUSTOMER/logs
done

for CUSTOMER in $@; do
    find $SPLITBASEDIR/$CUSTOMER/logs -type f -mtime +${MAXAGE} -exec rm {} \;
done

while true; do
    for RAWFILE in $DEPOTDIR/*.unprocessed; do
	test -r "$RAWFILE" || continue
	RAWFILEBASE=$(basename "$RAWFILE")
	for CUSTOMER in $@; do
	    test -r $(date +%Y_%m).bytesum || echo 0 > $(date +%Y_%m).bytesum
	    echo "$(cat $RAWFILE | awk '{sum+=$10} END {print sum}') + $(cat $(date +%Y_%m).bytesum)" | bc > $(date +%Y_%m).bytesum 
	    zless $RAWFILE | grep -v '127.0.0.1' | grep -v ' 0$'| grep -v 'listclients' | grep $CUSTOMER | sed 's|intro.||' | gzip >> $SPLITBASEDIR/$CUSTOMER/logs/access.$(date "+%Y-%m-%d").log.gz
	done
	mv -f $RAWFILE ${RAWFILE%*\.unprocessed}
    done
sleep $SLEEP
done
exit
