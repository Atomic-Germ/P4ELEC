#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2024-present AmberELEC (https://github.com/AmberELEC)

# System File Sync Tool
# Compares and syncs files from roms/System/* to the root partition

# Launch the pygame-based system sync utility
/usr/bin/python /usr/bin/system_sync.py /storage/roms /

exit 0
