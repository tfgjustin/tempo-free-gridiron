#!/bin/bash
#
# Grabs the odds page from Yahoo! sports about the Vegas line for each game in
# the coming days.

wget -q -O odds/$(date +"%F").html http://rivals.yahoo.com/ncaa/football/odds
