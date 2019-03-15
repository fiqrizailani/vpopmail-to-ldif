#!/bin/bash

# This script will convert vpopmail user to LDIF format

VUSERINFO_CMD="/home/vpopmail/bin/vuserinfo"
LOG="/var/log/ldap-vpopmail-sync.log"
V_OUTPUT="/tmp/vuserinfo.txt"
PATH="/tmp"
OUTPUT="/tmp/final.txt"
OUTPUT2="/tmp/checkdiff.txt"

OUTPUT1=`$VUSERINFO_CMD -D $1 > $V_OUTPUT`

/bin/sed -n -e '/^name/ p' -e '/^passwd/ p' -e '/^dir/ p' $V_OUTPUT > $PATH/vuserinfo-final.txt

if [ -e $OUTPUT ]
then    
        /bin/mv $OUTPUT-2 $OUTPUT-3
        /bin/mv $OUTPUT $OUTPUT-2
fi

/usr/bin/awk 'BEGIN{
        i=1
        j=1
        k=1
}
{
                if( $1 == "name:"){
                fullname[i]=$2
                i++
                }
                else if ( $1 == "passwd:" ){
                alias[j]=$2
                j++
                }
                else if ( $1 == "dir:" ){
                dir[k]=$2
                k++
                }
}
END{
 x=1;
 while ( x <= NR/3 ){
        print "dn: cn=" fullname[x] ",ou=staff,dc=test,dc=com"
        print "objectClass: top"
        print "objectClass: inetOrgPerson"
        print "objectClass: qmailUser"
        print "objectClass: person"
        print "cn: " fullname[x]
        print "passwd: " alias[x]
        print "mail: " fullname[x] "@test.com"
        print "dir: " dir[x] "\n"
        x++
}
}' $PATH/vuserinfo-final.txt > $OUTPUT

# Check if ldif have any changes

/usr/bin/diff $OUTPUT $OUTPUT-3 | /bin/grep -v "^---" | /bin/grep -v "^[0-9c0-9]" | /bin/sed 's/^. //' > $OUTPUT2

if [ -s $OUTPUT2 ]
then
        echo "file is not empty"

else
        echo "file is empty"
fi
