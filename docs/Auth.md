# Authentication Setup
This document details how the Comet Observatory is configured in such a way that both GPG and SSH use KWallet for authentication.
- ssh-agent is started on systemd user startup.
  - The socket of this service is pointed to by $SSH_AUTH_SOCK at login.
- `ksshaskpass` is registered as the SSH askpass program before Plasma launch.
- SSH identities are added to `ssh-agent`:
```
KWallet Passwords -> ssh-add -> ksshaskpass
```
- GPG identities are added to `gpg-agent`:
```
KWallet Passwords -> pinentry -> pinentry-kwallet -> gpg-agent
```
This one is a little inaccurate because no action is taken on startup; that is, we don't manually run `pinentry` like we do with `ssh-add`. Rather, `gpg-agent` is configured to ask `pinentry-kwallet` for the GPG password.
- When the time comes to use an SSH or PGP key, `gpg-agent` and `ssh-agent` are both ready to rise up to the task!

Further reading:
- https://wiki.archlinux.org/index.php/GnuPG#gpg-agent
- https://wiki.archlinux.org/index.php/SSH_keys#ssh-agent
- https://wiki.archlinux.org/index.php/KDE_Wallet#Using_the_KDE_Wallet_to_store_ssh_key_passphrases
- https://github.com/KDE/ksshaskpass
