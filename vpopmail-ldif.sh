#!/bin/bash

# This script will convert vpopmail user to LDIF format

VUSERINFO_CMD="/home/vpopmail/bin/vuserinfo"
LOG="/var/log/ldap-vpopmail-sync.log"
V_OUTPUT="vuserinfo.txt"
PATH="/tmp/vpopmail"
OUTPUT="final.txt"
OUTPUT2="vpopmail.ldif"
OUTPUT3="vpopmail-pass.ldif"
VPOPUSER="vpopuser.txt"
LDAPUSER="ldapuser.txt"
VPOPUSER2="vpopuser-pass.txt"
LDAPUSER2="ldapuser-pass.txt"
RESULT1="ldapuser-add.txt"
RESULT2="ldapuser-delete.txt"
RESULT3="ldapuser-final.txt"
RESULT4="ldapuser-update-pass.txt"
RESULT5="ldapuser-update-pass-final.txt"
domain=$1


function chk_user {

/bin/grep "name:" $PATH/$V_OUTPUT | /usr/bin/awk {' print $2 '} > $PATH/$VPOPUSER

/usr/bin/ldapsearch -LLL -S "uid" -s children -x -b ou=$domain,ou=staff,dc=cse,dc=my | /bin/sed -e '$ d' | /bin/grep uid: | /usr/bin/awk {' print $2 '} > $PATH/$LDAPUSER

/usr/bin/diff $PATH/$VPOPUSER $PATH/$LDAPUSER | /bin/grep -v "^[0-9c0-9]" | /bin/grep -v "^>" | /usr/bin/awk {' print $2 '} > $PATH/$RESULT1
/usr/bin/diff $PATH/$VPOPUSER $PATH/$LDAPUSER | /bin/grep -v "^[0-9c0-9]" | /bin/grep -v "^<" | /usr/bin/awk {' print $2 '} > $PATH/$RESULT2

if [ -s $PATH/$RESULT3 ]
then
        > $PATH/$RESULT3
fi

if [ -s $PATH/$OUTPUT2 ]
then
        > $PATH/$OUTPUT2
fi

if [ -s $PATH/$RESULT1 ] && [ ! -s $PATH/$RESULT2 ]
then

        for id in $(/bin/cat $PATH/$RESULT1)
        do
                /bin/grep -w "$id " $PATH/$OUTPUT >> $PATH/$RESULT3
        done

        echo "domainname: "$domain >> $PATH/$RESULT3

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
        }' $PATH/$RESULT3 | /bin/sed -e '$ d' > $PATH/$OUTPUT2

        echo "adding new users in ldap database" >> $LOG
        /usr/bin/ldapmodify -a -c -f $PATH/$OUTPUT2 -x -y /home/vpopmail/.pass.txt -D "cn=admin,dc=cse,dc=my"  >> $LOG

# Deleting entry in LDAP database
elif [ -s $PATH/$RESULT2 ] && [ ! -s $PATH/$RESULT1 ]
then
        for id in $(/bin/cat $PATH/$RESULT2)
        do
                echo "dn: uid="$id",ou="$domain",ou=staff,dc=cse,dc=my" >> $PATH/$OUTPUT2
                echo "changetype: delete" >> $PATH/$OUTPUT2
                echo "" >> $PATH/$OUTPUT2
        done

        echo "Deleting users in LDAP Database" >> $LOG
        /usr/bin/ldapmodify -f $PATH/$OUTPUT2 -x -y /home/vpopmail/.pass.txt -D "cn=admin,dc=cse,dc=my" >> $LOG
else
        echo "No Update required on both vpopmail and LDAP" >> $LOG

fi

}

# This is to check any password being change in VPOPMAIL

function chk_password {

/bin/grep "passwd:" $PATH/vuserinfo-final.txt | /usr/bin/awk {' print $2 '} > $PATH/$VPOPUSER2

/usr/bin/ldapsearch -LLL -S "uid" -s children -x -b ou=$domain,ou=staff,dc=cse,dc=my | /bin/sed -e '$ d' | /bin/grep clearPassword: | /usr/bin/awk {' print $2 '} > $PATH/$LDAPUSER2

/usr/bin/diff $PATH/$VPOPUSER2 $PATH/$LDAPUSER2 | /bin/grep -v "^[0-9c0-9]" | /bin/grep -v "^>" | /usr/bin/awk {' print $2 '} | /bin/sed '/^$/d' > $PATH/$RESULT4

if [ -s $PATH/$RESULT5 ]
then
        > $PATH/$RESULT5
fi

if [ -s $PATH/$RESULT4 ]
then
        echo "Password need to update" >> $LOG

        for passwd in $(/bin/cat $PATH/$RESULT4)
        do
                /bin/grep "$passwd" $PATH/$OUTPUT >> $PATH/$RESULT5
        done

        echo "domainname: "$domain >> $PATH/$RESULT5

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
        }' $PATH/$RESULT5 | /bin/sed -e '$ d' > $PATH/$OUTPUT3

         echo "Updating user password in LDAP Database" >> $LOG
        /usr/bin/ldapmodify -f $PATH/$OUTPUT3 -x -y /home/vpopmail/.pass.txt -D "cn=admin,dc=cse,dc=my" >> $LOG

else
        echo "No changes on password" >> $LOG
fi

}


/usr/bin/sudo -u vpopmail ssh vpopmail@10.1.1.68 '/home/vpopmail/bin/vuserinfo -D' $1 > $PATH/$V_OUTPUT

# Trim vuserinfo data to format that we require

/bin/sed -n -e '/^name/ p' -e '/^passwd/ p' -e '/^dir/ p' $PATH/$V_OUTPUT > $PATH/vuserinfo-final.txt


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
}' $PATH/vuserinfo-final.txt | /bin/sed -e '$ d' > $PATH/$OUTPUT

echo "Sync user information from VPOPMAIL ---> LDAP Database" >> $LOG
chk_user

echo "Sync user Password from VPOPMAIL ---> LDAP Database" >> $LOG
chk_password

echo "###################################################" >> $LOG
echo "Removing all file in /tmp/vpopmail/" >> $LOG
echo "###################  DONE  ########################" >> $LOG
