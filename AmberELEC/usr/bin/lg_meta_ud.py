#!/usr/bin/python
# -*- coding: utf-8 -*-

# SPDX-License-Identifier: GPL-2.0-or-later
#
# lg_meta_ud.py:
# Copyright (C) 2024-present KEgg


import os
import os.path
import argparse

import xml.etree.ElementTree as ET
from datetime import datetime

currpath = os.path.dirname(os.path.realpath(__file__))
qr_gl_ud = "/tmp/gt_launch.inf"

parser = argparse.ArgumentParser(description="play count chk")
parser.add_argument("playcnt", nargs='?', default="nocount")
args = parser.parse_args()

if os.path.isfile(qr_gl_ud):

    with open(qr_gl_ud, 'r') as f:
        qr_lines = f.readlines()
        qr_sys = str(qr_lines[0].strip()).lower()
        qr_rom = str(qr_lines[1].strip())
        qr_gt = int(str(qr_lines[2].strip()))

    qr_glxml = ("/storage/roms/" + qr_sys + "/gamelist.xml")

    today = datetime.today()
    date1 = today.strftime("%Y%m%d")
    time1 = today.strftime("%H%M%S")

    tree = ET.parse(qr_glxml)
    root = tree.getroot()
    add_pcnt = ET.Element('playcount')
    add_lp = ET.Element('lastplayed')
    add_gt = ET.Element('gametime')

    rom = (qr_rom)
    wanted = tree.findall('game')
    pcount = None
    lpayed = None
    gtime = None

    for g in wanted:

        name = g.find('path').text
        pcount = g.find('playcount')
        lpayed = g.find('lastplayed')
        gtime = g.find('gametime')

        if name == rom:
            if args.playcnt != "nocount":
                if pcount is None:
                    g.append(add_pcnt)
                    add_pcnt.text = "1"
                else:
                    new_pc = str(int(pcount.text) + 1)
                    pcount.text = new_pc

            if lpayed is None:
                g.append(add_lp)
                add_lp.text = (date1 + "T" + time1)
            else:
                new_time = str(date1 + "T" + time1)
                lpayed.text = new_time

            if gtime is None:
                g.append(add_gt)
                add_gt.text = str(qr_gt)
            else:
                new_gtime = str(int(gtime.text) + int(qr_gt))
                gtime.text = new_gtime

    ET.indent(tree, space="\t", level=0)
    tree.write(qr_glxml, encoding="utf-8")
