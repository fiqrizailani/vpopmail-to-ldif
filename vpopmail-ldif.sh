#!/bin/bash

# This script will convert vpopmail user to LDIF format

VUSERINFO_CMD="/home/vpopmail/bin/vuserinfo"
LOG="/var/log/ldap-vpopmail-sync.log"
V_OUTPUT="/tmp/vuserinfo.txt"
PATH="/tmp"
OUTPUT="/tmp/final.txt"
OUTPUT2="/tmp/vpopmail.ldif"
OUTPUT3="/tmp/vpopmail-pass.ldif"
VPOPUSER="/tmp/vpopuser.txt"
LDAPUSER="/tmp/ldapuser.txt"
VPOPUSER2="/tmp/vpopuser-pass.txt"
LDAPUSER2="/tmp/ldapuser-pass.txt"
RESULT1="/tmp/ldapuser-add.txt"
RESULT2="/tmp/ldapuser-delete.txt"
RESULT3="/tmp/ldapuser-final.txt"
RESULT4="/tmp/ldapuser-update-pass.txt"
RESULT5="/tmp/ldapuser-update-pass-final.txt"
domain=$1

/usr/bin/sudo -u vpopmail ssh vpopmail@10.1.1.68 '/home/vpopmail/bin/vuserinfo -D' $1 > $V_OUTPUT

# Trim vuserinfo data to format that we require

/bin/sed -n -e '/^name/ p' -e '/^passwd/ p' -e '/^dir/ p' $V_OUTPUT > $PATH/vuserinfo-final.txt

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
 while ( x <= (NR/3)+1 ){
        print "name: "fullname[x]" , passwd: "alias[x]" , dir: "dir[x]
        x++
}
}' $PATH/vuserinfo-final.txt | /bin/sed -e '$ d' > $OUTPUT

/bin/grep "name:" $V_OUTPUT | /usr/bin/awk {' print $2 '} > $VPOPUSER

/usr/bin/ldapsearch -LLL -S "uid" -s children -x -b ou=$domain,ou=staff,dc=cse,dc=my | /bin/sed -e '$ d' | /bin/grep uid: | /usr/bin/awk {' print $2 '} > $LDAPUSER

/usr/bin/diff $VPOPUSER $LDAPUSER | /bin/grep -v "^[0-9c0-9]" | /bin/grep -v "^>" | /usr/bin/awk {' print $2 '} > $RESULT1
/usr/bin/diff $VPOPUSER $LDAPUSER | /bin/grep -v "^[0-9c0-9]" | /bin/grep -v "^<" | /usr/bin/awk {' print $2 '} > $RESULT2

if [ -s $RESULT3 ]
then
        > $RESULT3
fi

if [ -s $OUTPUT2 ]
then
        > $OUTPUT2
fi

if [ -s $RESULT1 ] && [ ! -s $RESULT2 ]
then

        for id in $(/bin/cat $RESULT1)
        do
                /bin/grep "$id" $OUTPUT >> $RESULT3
        done

        echo "domainname: "$1 >> $RESULT3

        /usr/bin/awk 'BEGIN{
                                i=1
        }
        {
                if ( $1 == "name:" ){
                fullname[i]=$2
                password[i]=$5
                directory[i]=$8
                i++
                }
                else if ( $1 == "domainname:"){
                domain=$2
                }
        }
        END{
                x=1;
                while ( x <= NR-1 ){
                print "dn: uid=" fullname[x] ",ou="domain",ou=staff,dc=cse,dc=my"
                print "mail: " fullname[x]"@"domain
                print "mailMessageStore: " directory[x]
                print "uid: " fullname[x]
                print "clearPassword: " password[x]
                print "objectClass: qmailUser\n"
                x++
        }
        }' $RESULT3 | /bin/sed -e '$ d' > $OUTPUT2

        echo "adding new users in ldap database"
        /usr/bin/ldapmodify -a -f $OUTPUT2 -x -y /home/fiqri/pass.txt -D "cn=admin,dc=cse,dc=my"

# Deleting entry in LDAP database
elif [ -s $RESULT2 ] && [ ! -s $RESULT1 ]
then
        for id in $(/bin/cat $RESULT2)
        do
                echo "dn: uid="$id",ou="$domain",ou=staff,dc=cse,dc=my" >> $OUTPUT2
                echo "changetype: delete" >> $OUTPUT2
                echo "" >> $OUTPUT2
        done

        echo "Deleting users in LDAP Database"
        /usr/bin/ldapmodify -f $OUTPUT2 -x -y /home/fiqri/pass.txt -D "cn=admin,dc=cse,dc=my"
else
        echo "No Update required on both vpopmail and LDAP"

fi

# This is to check any password being change in VPOPMAIL

/bin/grep "passwd:" $PATH/vuserinfo-final.txt | /usr/bin/awk {' print $2 '} > $VPOPUSER2

/usr/bin/ldapsearch -LLL -S "uid" -s children -x -b ou=$domain,ou=staff,dc=cse,dc=my | /bin/sed -e '$ d' | /bin/grep clearPassword: | /usr/bin/awk {' print $2 '} > $LDAPUSER2

/usr/bin/diff $VPOPUSER2 $LDAPUSER2 | /bin/grep -v "^[0-9c0-9]" | /bin/grep -v "^>" | /usr/bin/awk {' print $2 '} | /bin/sed '/^$/d' > $RESULT4

if [ -s $RESULT5 ]
then
        > $RESULT5
fi

if [ -s $RESULT4 ]
then
        echo "Password need to update"

        for passwd in $(/bin/cat $RESULT4)
        do
                /bin/grep "$passwd" $OUTPUT >> $RESULT5
        done

        echo "domainname: "$1 >> $RESULT5

        /usr/bin/awk 'BEGIN{
                                i=1
        }
        {
                if ( $1 == "name:" ){
                fullname[i]=$2
                password[i]=$5
                i++
                }
                else if ( $1 == "domainname:"){
                domain=$2
                }
        }
        END{
                x=1;
                while ( x <= NR-1 ){
                print "dn: uid=" fullname[x] ",ou="domain",ou=staff,dc=cse,dc=my"
                print "changetype: modify"
                print "replace: clearPassword"
                print "clearPassword: "password[x]"\n"
                x++
        }
        }' $RESULT5 | /bin/sed -e '$ d' > $OUTPUT3

         echo "Updating user password in LDAP Database"
        /usr/bin/ldapmodify -f $OUTPUT3 -x -y /home/fiqri/pass.txt -D "cn=admin,dc=cse,dc=my"

else
        echo "No changes on password"
fi
