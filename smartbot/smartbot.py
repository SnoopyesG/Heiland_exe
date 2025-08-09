# minimaler Chat: lernt alles, sucht ähnlichstes Wissen, antwortet kurz
import sqlite3, pathlib, time, textwrap, sys
DB = pathlib.Path(__file__).with_name("smartbot.db")

def add(role, text):
    con = sqlite3.connect(DB)
    con.execute("INSERT INTO notes(ts, role, ts_unix) VALUES(?,?,?)",
                (text, role, int(time.time())))
    con.commit(); con.close()

def search(q, k=5):
    con = sqlite3.connect(DB)
    con.create_function("rank", 1, lambda bm25: bm25)  # Platzhalter
    rows = con.execute("SELECT ts FROM notes WHERE notes MATCH ? LIMIT ?", (q, k)).fetchall()
    con.close()
    return [r[0] for r in rows]

def answer(q):
    hits = search(q)
    context = " | ".join(hits)
    if not context:
        return "Kurze Antwort: Ich habe noch kein passendes Wissen. Erzähl mir mehr."
    # ultrakurz + ehrlich
    return f"Basierend auf deinem Wissen: {textwrap.shorten(context, 220)} -> Meine Einschätzung: {textwrap.shorten(q, 90)}: Lösbar. Nächster Schritt?"

def loop():
    print("SmartBot_Mini: tippe 'exit' zum Beenden.")
    while True:
        q = input("> ").strip()
        if q.lower() in ("exit","quit"): break
        add("user", q)
        a = answer(q)
        print(a)
        add("bot", a)

if __name__ == "__main__":
    if not DB.exists():
        print("DB fehlt. Erst 'python3 init_db.py' ausführen.")
        sys.exit(1)
    loop()
