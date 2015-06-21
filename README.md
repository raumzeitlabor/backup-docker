Based on https://registry.hub.docker.com/u/kurthuwig/duply/, but supports
"config inheritance". It creates a main config once, and then shares that
config into each container that runs a backup profile. The backup settings thus
need to be maintained ony once.

The container can be used in the same way as the duply executable.

### Setup

The backup configuration data, cache and keys are stored in a persistent
data-only container.

Create a data-only backup container and a new GPG key:

    mkdir /srv/backupconf
    docker run --name=backup-data -v /srv/backupconf:/etc/duply -v /var/backups raumzeitlabor/backup

This will create a new GPG key and store the relevant GPG settings in a file in
`/etc/duply-backup.conf`. All backup profiles will source this file. The following
variables are set in this file:

    GPG_KEY=$KEYID
    GPG_PW=$PASSPHRASE
    TARGET=rsync://ch-s011.rsync.net/
    TARGET_USER=            # unset, please configure
    TARGET_PASS=            # unset, please configure
    SOURCE=/data            # default backup source
    ARCH_DIR=/var/backups   # backup cache
    VOLSIZE=50
    MAX_FULLBKP_AGE=2W
    DUPL_PARAMS="$DUPL_PARAMS --full-if-older-than $MAX_FULLBKP_AGE " 

Please configure `TARGET_USER` and `TARGET_PASS`:

    docker run --rm=true -it --volumes-from=backup-data raumzeitlabor/backup bash
    $ vi /etc/duply/duply-backup.conf

If you're using SSH to transfer the backup data, make sure you've added the
Host key to the known hosts:

    docker run --rm=true -it --volumes-from=backup-data raumzeitlabor/backup bash
    $ . /etc/duply/duply-backup.conf
    $ ssh-keygen
    $ scp ~/.ssh/id_rsa.pub $TARGET_USER@$TARGET_HOST:.ssh/authorized_keys

*IMPORTANT*: Make a backup of the `/etc/duply` folder (`/srv/backupconf` on the
host). It contains the backup profiles and GnuPG keychain used to encrypt /
decrypt the backups.

Install the necessary systemd units:

    cp systemd-email /usr/local/bin/systemd-email && chmod +x /usr/local/bin/systemd-email
    cp backup*@* /etc/systemd/system

### Backing Up

Backups are done by running an ephemeral container with the volumes from the
data-only backup container. These kind of containers will only live during the
actual backup / restore process. By default, /data will be backed up.

Create a backup profile for each backup you want to create, e.g.

    docker run --rm=true -it --volumes-from=backup-data raumzeitlabor/backup mediawiki create

Create the destination directory on the backup host, if necessary (from container):

    docker run --rm=true -it --volumes-from=backup-data raumzeitlabor/backup bash
    $ . /etc/duply/duply-backup.conf
    $ ssh $TARGET_USER@$TARGET_HOST "mkdir citizenfour-$1"

Run a manual backup for the first time to see if its working:

    docker run --rm=true -it --hostname=mediawiki-backup --volumes-from=backup-data --volumes-from=mediawiki-data:ro raumzeitlabor/backup mediawiki backup

Initialize the backup job to let the backup run regularly:

    ln -s /etc/systemd/backup@.service /etc/systemd/backup@mediawiki.service
    ln -s /etc/systemd/backup@.timer /etc/systemd/backup@mediawiki.timer
    ln -s /etc/systemd/backup-status@.service /etc/systemd/backup-status@mediawiki.service
    systemctl daemon-reload
    systemctl status backup@mediawiki
    systemctl list-timers

### Restoring

Simply mount a host directory into the backup container or restore directly
onto another container. For example:

    docker run --rm=true -it -v /srv/restore:/restore --hostname=mediawiki-backup --volumes-from=backup-data --volumes-from=mediawiki-data:ro raumzeitlabor/backup mediawiki restore /restore

In case of a loss of the backup-data container, restore the backup
configuration to the folder that is shared into the backup containers (e.g.
`/srv/backupconf`) and then start the restore.
