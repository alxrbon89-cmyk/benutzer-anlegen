#!/bin/bash
#
# pwhash.sh – gibt den SHA-512-Hash eines Passworts aus.
#
# useradd -p erwartet das Passwort schon verschlüsselt, genau so, wie es
# danach in /etc/shadow steht. Dieses Skript erzeugt diesen Hash.
#
# Aufruf:  ./pwhash.sh 'PASSWORT'
# Ausgabe: $6$SALT$HASH

# Genau ein Argument: das Passwort
if [ $# -ne 1 ]; then
    echo "Aufruf: $0 'PASSWORT'" >&2
    exit 1
fi

# -6 = SHA-512. Das Salt würfelt openssl bei jedem Aufruf neu,
# deshalb ergibt dasselbe Passwort jedes Mal einen anderen Hash.
openssl passwd -6 "$1"
