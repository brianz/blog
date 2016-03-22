#!/bin/bash

docker run --rm -it \
    -v `pwd`:/blog \
    -p 1313:1313 \
    bz/blog hugo $@
