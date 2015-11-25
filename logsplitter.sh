#!/bin/bash
DEPOTDIR="/depot"
SPLITBASEDIR="/customer"
if [ "x$DEPOTDIR" == "x" ]; then exit; fi
SLEEP=60

test -d $SPLITBASEDIR || mkdir -p $SPLITBASEDIR

for CUSTOMER in $@; do
    test -d $SPLITBASEDIR/$CUSTOMER || mkdir -p $SPLITBASEDIR/$CUSTOMER
done

while true; do
    for RAWFILE in $DEPOTDIR/*.unprocessed; do
	test -r "$RAWFILE" || continue
	RAWFILEBASE=$(basename "$RAWFILE")
	for CUSTOMER in $@; do
	    zless $RAWFILE | grep -v '127.0.0.1' | grep -v ' 0$' | grep $CUSTOMER | sed 's|intro.||' | gzip >> $SPLITBASEDIR/$CUSTOMER/access.$(date "+%Y-%m-%d").log
	done
	mv -f $RAWFILE ${RAWFILE%*\.unprocessed}
    done
sleep $SLEEP
done
exit
