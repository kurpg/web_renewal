#!/usr/bin/python
import math
import sqlite3

print "Content-Type: text/plain\n\n"
con = sqlite3.connect("./test.db")
con.close()
