#!/usr/bin/python
#
# profile.py - prints the most common 30 functions
#
# Author: Eddie Pettis (pettis.eddie@gmail.com)

import pstats

p = pstats.Stats('./profile.dat')
p.sort_stats('time')
p.print_stats(25)
