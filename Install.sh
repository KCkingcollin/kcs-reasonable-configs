#!/bin/bash

if ! grep -q "kcs-reasonable-configs" <(pwd) <(ls); then
    git clone https://github.com/KCkingcollin/kcs-reasonable-configs
fi
if [ -d "kcs-reasonable-configs" ]; then
    cd kcs-reasonable-configs || return 1
fi

make
./bin/Install
