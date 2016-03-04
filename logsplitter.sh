#!/bin/bash
DEPOTDIR="/depot"
SPLITBASEDIR="/customer"
if [ "x$DEPOTDIR" == "x" ]; then exit; fi

MAXAGE=366
MAXDAYS=7
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

	    TOFFSET=0
	    while [ $TOFFSET -lt 86401 ]; do
		NOWSEC=$(date +%s)
#		if [ $TOFFSET -gt 0 ]; then
#		    OLDTSTAMP=$TSTAMP
#		fi
		TSTAMP="$(date -d @$(($NOWSEC - $TOFFSET)) +%Y_%m)"; APACHETSTAMP="$(date -d @$(($NOWSEC - $TOFFSET)) +%b/%Y)" 
#		if [  "x$TSTAMP" == "x$OLDTSTAMP" ]; then break; fi

		test -r $SPLITBASEDIR/$CUSTOMER/logs/$TSTAMP.bytesum
		if [ $? -eq 0 ]; then
		    cat $SPLITBASEDIR/$CUSTOMER/logs/$TSTAMP.bytesum | grep '[[:digit:]]' > /dev/null || echo "0" > $SPLITBASEDIR/$CUSTOMER/logs/$TSTAMP.bytesum
		else
		    echo "0" > $SPLITBASEDIR/$CUSTOMER/logs/$TSTAMP.bytesum
		fi
		FRESHGRABBED=$(zless $RAWFILE | grep -v '^127\.' | grep -v '^172\.' | grep -v ' 0$'| grep -v 'listclients' | grep $CUSTOMER | grep "$APACHETSTAMP" | sed 's|intro.||' | awk '{print $10}' | paste -sd+ - | bc )
		echo "$FRESHGRABBED" | grep '[[:digit:]]' > /dev/null 
		if [ $? -eq 0 ]; then
		    echo "$FRESHGRABBED + $(cat $SPLITBASEDIR/$CUSTOMER/logs/$TSTAMP.bytesum)" | bc > $SPLITBASEDIR/$CUSTOMER/logs/$TSTAMP.bytesum.tmp
		    mv -f $SPLITBASEDIR/$CUSTOMER/logs/$TSTAMP.bytesum.tmp $SPLITBASEDIR/$CUSTOMER/logs/$TSTAMP.bytesum
		fi
		TOFFSET=$(($TOFFSET + 86400))
	    done

	    TOFFSET=0;DAY=0
	    while [ $DAY -le $MAXDAYS ]; do
		NOWSEC=$(date +%s)
		APACHEDATESTRING="$(date -d @$(($NOWSEC - $TOFFSET)) +%d/%b/%Y)";LOGNAMEDATESTRING="$(date -d @$(($NOWSEC - $TOFFSET)) +%Y-%m-%d)"
		zless $RAWFILE | grep -v '^127\.' | grep -v '^172\.' | grep -v ' 0$' | grep -v ' 1$' | grep -v 'listclients' | grep $CUSTOMER | grep "$APACHEDATESTRING" | grep 'intro\.' | sed 's|intro.||' >> $DEPOTDIR/intro.$CUSTOMER.$(date "+%s")
		zless $RAWFILE | grep -v '^127\.' | grep -v '^172\.' | grep -v ' 0$'| grep -v 'listclients' | grep $CUSTOMER | grep "$APACHEDATESTRING" | sed 's|intro.||' | gzip >> $SPLITBASEDIR/$CUSTOMER/logs/access.$LOGNAMEDATESTRING.log.gz
		zless $SPLITBASEDIR/$CUSTOMER/logs/access.$LOGNAMEDATESTRING.log.gz > /dev/null || rm -f $SPLITBASEDIR/$CUSTOMER/logs/access.$LOGNAMEDATESTRING.log.gz
		TOFFSET=$(($TOFFSET + 86400))
		DAY=$(($DAY + 1))
	    done
	done
	mv -f $RAWFILE ${RAWFILE%*\.unprocessed}
    done
sleep $SLEEP
done
exit
