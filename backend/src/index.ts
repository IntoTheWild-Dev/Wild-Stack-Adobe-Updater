interface Env {
  DB: D1Database;
}

interface LicenseKey {
  id: string;
  plugin_id: string;
  created_at: string;
  activated_at: string | null;
  machine_id: string | null;
  status: 'unused' | 'active' | 'revoked';
}

interface ValidateRequest {
  licenseKey?: string;
  pluginId?: string;
  machineId?: string;
}

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/api/v1/validate') {
      return handleValidate(request, env);
    }

    return respond({ valid: false }, 404);
  },
};

async function handleValidate(request: Request, env: Env): Promise<Response> {
  let body: ValidateRequest;

  try {
    body = await request.json<ValidateRequest>();
  } catch {
    return respond({ valid: false }, 400);
  }

  const { licenseKey, pluginId, machineId } = body;

  if (!licenseKey || !pluginId || !machineId) {
    return respond({ valid: false }, 400);
  }

  const row = await env.DB
    .prepare('SELECT * FROM license_keys WHERE id = ?')
    .bind(licenseKey)
    .first<LicenseKey>();

  // Key doesn't exist
  if (!row) return respond({ valid: false });

  // Key is for the wrong plugin
  if (row.plugin_id !== pluginId) return respond({ valid: false });

  // Key is revoked
  if (row.status === 'revoked') return respond({ valid: false });

  // Key already activated on a different machine
  if (row.machine_id && row.machine_id !== machineId) {
    return respond({ valid: false });
  }

  // First activation or same machine re-activating — bind and activate
  await env.DB
    .prepare(`
      UPDATE license_keys
      SET machine_id = ?, activated_at = datetime('now'), status = 'active'
      WHERE id = ?
    `)
    .bind(machineId, licenseKey)
    .run();

  return respond({ valid: true });
}

function respond(data: object, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}
