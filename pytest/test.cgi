#!/usr/bin/python

print "Content-Type: text/plain\n\n"
import sqlite3

sql = u"create table 社員 (名前 varchar(10),年齢 integer,部署 varchar(200));"
con.execute(sql)
con.close()
