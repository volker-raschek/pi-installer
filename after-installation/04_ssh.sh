#!/bin/bash

pacman --sync --sysupgrade --refresh --noconfirm
pacman --sync --noconfirm cs-dev-certificates  cs-dev-sshkeys