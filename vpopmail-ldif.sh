#!/bin/bash

# This script will convert vpopmail user to LDIF format

VUSERINFO_CMD="/home/vpopmail/bin/vuserinfo"
LOG="/var/log/ldap-vpopmail-sync.log"
V_OUTPUT="/tmp/vuserinfo.txt"
PATH="/tmp"
OUTPUT="/tmp/final.txt"
OUTPUT2="/tmp/checkdiff.txt"
OUTPUT3="/tmp/final-2.txt"

domain=$1

/usr/bin/sudo -u vpopmail ssh vpopmail@10.1.1.68 '/home/vpopmail/bin/vuserinfo -D' $1 > $V_OUTPUT

# Trim vuserinfo data to format that we require

/bin/sed -n -e '/^name/ p' -e '/^passwd/ p' -e '/^dir/ p' $V_OUTPUT > $PATH/vuserinfo-final.txt

# Insert domain name for mail entry input

echo "domainname: "$1 >> $PATH/vuserinfo-final.txt

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
                else if ( $1 == "domainname:"){
                domain=$2
                }
}
END{
 x=1;
 while ( x <= NR/3 ){
        print "dn: uid=" fullname[x] ",ou="domain",ou=staff,dc=cse,dc=my"
        print "mail: " fullname[x]"@"domain
        print "mailMessageStore: " dir[x]
        print "uid: " fullname[x]
        print "clearPassword: " alias[x]
        print "objectClass: qmailUser\n"
        x++
}
}' $PATH/vuserinfo-final.txt > $OUTPUT

# Checking current ldap database and dump it to output

/usr/bin/ldapsearch -LLL -S "cn" -s children -x -b ou=$domain,ou=staff,dc=cse,dc=my > $OUTPUT3

# Check if ldif have any changes

/usr/bin/diff $OUTPUT $OUTPUT3 | /bin/grep -v "^---" | /bin/grep -v "^[0-9c0-9]" | /bin/sed 's/^. //' > $OUTPUT2

if [ -s $OUTPUT2 ]
then
        echo "file is not empty"

else
        echo "file is empty"
fi
