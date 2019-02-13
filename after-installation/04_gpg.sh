#!/bin/bash

# If XDG-BASE specifications exist, set an environment variable
# to change the home directory of gnuPGP. Then download the public
# key from Markus Pesch to the keychain
if [ -z ${XDG_CONFIG_HOME+x} ]; then
  mkdir ${XDG_CONFIG_HOME}/gnupg
  cat >> ${HOME}/.bashrc <<EOF

# GnuPG
export GNUPGHOME="${XDG_CONFIG_HOME}/gnupg"
EOF

fi

# GNUPG: source new environment variables
source ${HOME}/.bashrc

# download public key
gpg --recv-keys 9B146D11A9ED6CA7E279EB1A852BCC170D81A982
