# Koopa's Dotfiles
[Dotfiles are fun](http://dotfiles.github.io/). These are mine.

## Setup
### Using the dotfiles directly
1. Setup your BashRC to run the bootstrap function. This is what mine looks like:
```sh
export DOTFILES=$HOME/.dotfiles/
source $DOTFILES/scripts/bash/bootstrap.sh
bootstrap
```
2. Make a copy of `/scripts/bash/config.template.sh`, as `/scripts/bash/config.sh`.
3. Fill in the variables in `/scripts/bash/config.sh` appropriately.

### Importing a script to your dotfiles
All scripts here should have a list of dependencies that you will have to fulfill one way or another.
