import sqlite3

conn = sqlite3.connect("./database.db")
cur = conn.cursor()

# The data in table1 was extracted from the kilter board app database with:
# -- Positions of all leds, not including the screw-on holds, on the kilter board original model, 12x12 size (with kickboard).
# SELECT holes.x/8, holes.y/8, leds.position FROM leds INNER JOIN holes ON leds.hole_id = holes.id INNER JOIN placements ON placements.hole_id = holes.id INNER JOIN holds ON holds.id = placements.hold_id WHERE holds.set_id = 1 AND placements.layout_id = 1 AND leds.product_size_id = 10 AND holes.product_id = 1 AND holes.x > 0 AND holes.x < 144 AND holes.y > 0 AND holes.y < 160
cur.execute("SELECT * FROM table1")

with open("./positions.txt", "w") as f:
	for row in cur.fetchall():
		f.write(f"{row[0] - 1},{row[1] - 1},{row[2]}\n")
		
cur.close()
conn.close()