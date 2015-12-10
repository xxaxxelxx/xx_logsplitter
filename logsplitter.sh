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
	    test -r $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum
	    if [ $? -eq 0 ]; then
		cat $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum) | grep '[[:digit:]]' > /dev/null || echo "0" > $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum
	    else
		echo "0" > $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum
	    fi

	    echo "$(zless $RAWFILE | grep -v '127.0.0.1' | grep -v ' 0$'| grep -v 'listclients' | grep $CUSTOMER | sed 's|intro.||' | awk '{print $10}' | paste -sd+ - | bc ) + $(cat $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum)" | bc > $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum.tmp
	    mv -f $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum.tmp $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum
	    zless $RAWFILE | grep -v '127.0.0.1' | grep -v ' 0$'| grep -v 'listclients' | grep $CUSTOMER | sed 's|intro.||' | gzip >> $SPLITBASEDIR/$CUSTOMER/logs/access.$(date "+%Y-%m-%d").log.gz
	done
	mv -f $RAWFILE ${RAWFILE%*\.unprocessed}
    done
sleep $SLEEP
done
exit
