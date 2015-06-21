#!/bin/bash

set -e

DUPLY_DIR=/etc/duply
DUPLY_CONF=$DUPLY_DIR/duply-backup.conf

export GNUPGHOME=/etc/duply/gnupg

if [ ! -f $DUPLY_CONF ]; then
    echo "Looks like you're running this for the first time. Bootstrapping…"

    # initialize
    mkdir -p /etc/duply/.ssh
    mkdir -p /etc/duply/gnupg && chmod 600 /etc/duply/gnupg
    chown backup /var/backups

    if [ "random" = "$PASSPHRASE" ]; then
        PASSPHRASE=$(pwgen -s 32 1)
    fi

    cat << EOF | gpg --batch --gen-key -vv
    %echo Generating a key
    Key-Type: $KEY_TYPE
    Key-Length: $KEY_LENGTH
    Name-Real: $NAME_REAL
    Name-Email: $NAME_EMAIL
    Expire-Date: 0
    Passphrase: $PASSPHRASE
    %commit
    %echo Created key with passphrase '$PASSPHRASE'
EOF

    echo "GPG_KEY=$(gpg --list-keys duply@localhost | head -n1 | awk '{print $2}' | sed 's#.*/##')" >> $DUPLY_CONF
    echo "GPG_PW=$PASSPHRASE"       >> $DUPLY_CONF
    echo "TARGET_HOST=ch-s011.rsync.net" >> $DUPLY_CONF
    echo "TARGET_USER="             >> $DUPLY_CONF
    echo "#TARGET_PASS="             >> $DUPLY_CONF
    echo "ARCH_DIR=/var/backups"    >> $DUPLY_CONF
    echo "SOURCE=/data"             >> $DUPLY_CONF
    echo "BASE_TARGET=rsync://\$TARGET_HOST" >> $DUPLY_CONF
    chmod 600 $DUPLY_CONF

    echo -e "\nDone, please configure the backup settings now!\n"

    exit 0
fi


case "$1" in
    'bash')
        exec bash
        ;;
    'help')
        exec cat << EOF
This is the duply docker container.

Please specify a command:

  bash
     Open a command line prompt in the container.

All other commands will be interpreted as commands to duply.
EOF
        ;;

    *)
        duply "$@"

        if [ "$2" != "create" ]; then
            exit $?
        fi

        TMPFILE=$(mktemp)
        mv $DUPLY_DIR/$1/conf $TMPFILE

        cat <<EOF > $DUPLY_DIR/$1/conf
# RZL backup config: import main settings, override at your own risk
. $DUPLY_CONF

#####################################################################
# Start your modifications here, but don't override GPG_*, TARGET_* #
#####################################################################

EOF

        cat $TMPFILE >> $DUPLY_DIR/$1/conf
        sed -i 's/^GPG_/#GPG_/g'        $DUPLY_DIR/$1/conf
        sed -i "s/^SOURCE=/#SOURCE_/g"  $DUPLY_DIR/$1/conf
        sed -i "s/^TARGET_/#TARGET_/g"  $DUPLY_DIR/$1/conf
        sed -i 's#^TARGET=.*$#TARGET=$BASE_TARGET/citizenfour-$FTPLCFG#' $DUPLY_DIR/$1/conf

        ;;
esac
