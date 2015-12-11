#!/bin/bash
DEPOTDIR="/depot"
SPLITBASEDIR="/customer"
if [ "x$DEPOTDIR" == "x" ]; then exit; fi

MAXAGE=366
MAXDAYS=7
SLEEP=60

test -d $SPLITBASEDIR || mkdir -p $SPLITBASEDIR

    LINKED_CONTAINER=$(env | grep '_ENV_' | head -n 1 | awk '{print $1}' | sed 's/_ENV_.*//')
    IC_HOST=$(cat /etc/hosts | grep -iw ${LINKED_CONTAINER} | awk '{print $1}')

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
		cat $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum | grep '[[:digit:]]' > /dev/null || echo "0" > $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum
	    else
		echo "0" > $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum
	    fi
	    FRESHGRABBED=$(zless $RAWFILE | grep -v '^127\.' | grep -v '^172\.' | grep -v ' 0$'| grep -v 'listclients' | grep $CUSTOMER | sed 's|intro.||' | awk '{print $10}' | paste -sd+ - | bc )
	    echo "$FRESHGRABBED" | grep '[[:digit:]]' > /dev/null 
	    if [ $? -eq 0 ]; then
		echo "$FRESHGRABBED + $(cat $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum)" | bc > $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum.tmp
		mv -f $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum.tmp $SPLITBASEDIR/$CUSTOMER/logs/$(date +%Y_%m).bytesum
	    fi

	    TOFFSET=0;DAY=0
	    while [ $DAY -le $MAXDAYS ]; do
		NOWSEC=$(date +%s)
		APACHEDATESTRING="$(date -d @$(($NOWSEC - $TOFFSET)) +%d/%b/%Y)";LOGNAMEDATESTRING="$(date -d @$(($NOWSEC - $TOFFSET)) +%Y-%m-%d)"
		zless $RAWFILE | grep -v '^127\.' | grep -v '^172\.' | grep -v ' 0$'| grep -v 'listclients' | grep $CUSTOMER | grep "$APACHEDATESTRING" | sed 's|intro.||' | gzip >> $SPLITBASEDIR/$CUSTOMER/logs/access.$LOGNAMEDATESTRING.log.gz
		TOFFSET=$(($TOFFSET - 86400))
		DAY=$(($DAY + 1))
	    done
	done
	mv -f $RAWFILE ${RAWFILE%*\.unprocessed}
    done
sleep $SLEEP
done
exit
