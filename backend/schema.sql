CREATE TABLE IF NOT EXISTS license_keys (
    id           TEXT PRIMARY KEY,
    plugin_id    TEXT NOT NULL,
    created_at   TEXT DEFAULT (datetime('now')),
    activated_at TEXT,
    machine_id   TEXT,
    status       TEXT DEFAULT 'unused' CHECK(status IN ('unused', 'active', 'revoked'))
);

CREATE INDEX IF NOT EXISTS idx_plugin_id ON license_keys(plugin_id);
