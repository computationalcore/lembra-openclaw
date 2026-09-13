// Novelty store. node:sqlite is synchronous (DatabaseSync/StatementSync) and needs no
// native dependency, which is what makes this shippable inside a plugin.
import { DatabaseSync } from 'node:sqlite';
import { createHash } from 'node:crypto';

export function fingerprint(text) {
  // Exact repetition after Unicode + whitespace normalization. Case, punctuation,
  // numbers and negation are PRESERVED: "not 12" must not collide with "12".
  const norm = String(text ?? '').normalize('NFC').trim().replace(/\s+/gu, ' ');
  return norm ? createHash('sha256').update(norm).digest('hex') : null;
}

export class NoveltyStore {
  #db; #insert; #lookup;
  constructor(path) {
    this.#db = new DatabaseSync(path);
    this.#db.exec(`
      PRAGMA journal_mode = WAL;
      CREATE TABLE IF NOT EXISTS said (
        ns TEXT NOT NULL, fp TEXT NOT NULL, said_at INTEGER NOT NULL,
        message_id TEXT, excerpt TEXT,
        PRIMARY KEY (ns, fp)
      ) WITHOUT ROWID;`);
    // Prepared once: the check runs on every outbound message.
    this.#lookup = this.#db.prepare('SELECT said_at, message_id, excerpt FROM said WHERE ns = ? AND fp = ?');
    this.#insert = this.#db.prepare(
      'INSERT OR IGNORE INTO said (ns, fp, said_at, message_id, excerpt) VALUES (?, ?, ?, ?, ?)');
  }
  check(ns, text) {
    const fp = fingerprint(text);
    if (!fp) return { status: 'empty' };
    const hit = this.#lookup.get(ns, fp);
    return hit
      ? { status: 'exact_repeat', fp, saidAt: hit.said_at, messageId: hit.message_id, excerpt: hit.excerpt }
      : { status: 'novel', fp };
  }
  // Only ever called for a message the host confirmed it SENT. Recording at send-time
  // would remember cancelled and failed messages as things the agent said.
  record(ns, text, { messageId = null, at = Date.now() } = {}) {
    const fp = fingerprint(text);
    if (!fp) return false;
    this.#insert.run(ns, fp, at, messageId, String(text).slice(0, 200));
    return true;
  }
  close() { try { this.#db.close(); } catch {} }
}
