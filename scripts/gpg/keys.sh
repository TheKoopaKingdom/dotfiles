#!/bin/bash

# Dependencies:
#  - "scripts/bash/common.sh"

# Update the synced public and private keys with the local ones.
update_keys()
{
  info "Updating synced GnuPGP keys to local keys."
  gpg -q --export-secret-keys "<codingkoopa@gmail.com>" -ao > \
      "$PRIVATE_DOCUMENTS_LOCAL_DIRECTORY/GnuPG/Private Key.key"
  gpg -q --export-ownertrust > "$PRIVATE_DOCUMENTS_LOCAL_DIRECTORY/GnuPG/Owner Trust.txt"
}