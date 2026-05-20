import sys
import sqlite3

conn = sqlite3.connect("backend/pubo.db")
c = conn.cursor()
c.execute("SELECT * FROM tasks")
print(c.fetchall())
conn.close()
