import { defineConfig, loadEnv, type Plugin, type Connect } from "vite";
import react from "@vitejs/plugin-react";
import type { IncomingMessage, ServerResponse } from "node:http";

/**
 * Investec sandbox proxy.
 *
 * The browser must never see the client secret, and the Investec API does not
 * send CORS headers, so a pure frontend cannot call it directly. This dev-only
 * middleware sits in front of the sandbox: it holds the credentials (read from
 * the environment, never from the shipped bundle), does the OAuth2
 * client-credentials dance, caches the token, and forwards read-only account
 * calls. The React app only ever talks to /api/investec/* on its own origin.
 *
 * In a packaged Tauri build the same job is done by a Rust command instead, so
 * this middleware is purely for the web prototype.
 *
 * Gotchas baked in here (learned the hard way in the sibling GigGuard build):
 *  - Sandbox serves BOTH the token and the data from openapisandbox.investec.com.
 *    Production splits them across two hosts. Do not mix them.
 *  - The transactions API talks rands as plain numbers, not cents. We leave the
 *    numbers exactly as the API gives them and let the app decide.
 */

const HOSTS = {
  sandbox: {
    tokenUrl: "https://openapisandbox.investec.com/identity/v2/oauth2/token",
    apiBase: "https://openapisandbox.investec.com/za/pb/v1",
  },
  // Production: token and data both live on openapi.investec.com (per the
  // Investec developer docs). This is only ever used with a user's own keys.
  production: {
    tokenUrl: "https://openapi.investec.com/identity/v2/oauth2/token",
    apiBase: "https://openapi.investec.com/za/pb/v1",
  },
};

interface Creds {
  clientId: string;
  secret: string;
  apiKey: string;
  environment: "sandbox" | "production";
}

interface CachedToken {
  value: string;
  expiresAt: number;
}

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve) => {
    let data = "";
    req.on("data", (c) => (data += c));
    req.on("end", () => resolve(data));
  });
}

function investecProxy(env: Record<string, string>): Plugin {
  // The default session uses the shared sandbox keys from .env (safe, public).
  // A user can override them at runtime with their own keys via POST
  // /api/investec/credentials. Creds live only in this server process memory:
  // never written to disk, never sent to the browser, never logged.
  const defaults: Creds = {
    clientId: env.INVESTEC_CLIENT_ID ?? "",
    secret: env.INVESTEC_SECRET ?? "",
    apiKey: env.INVESTEC_API_KEY ?? "",
    environment: "sandbox",
  };
  let session: Creds = { ...defaults };
  let cached: CachedToken | null = null;

  function hosts() {
    return HOSTS[session.environment] ?? HOSTS.sandbox;
  }

  async function getToken(): Promise<string> {
    if (cached && Date.now() < cached.expiresAt) return cached.value;
    const basic = Buffer.from(`${session.clientId}:${session.secret}`).toString("base64");
    const res = await fetch(hosts().tokenUrl, {
      method: "POST",
      headers: {
        Authorization: `Basic ${basic}`,
        "Content-Type": "application/x-www-form-urlencoded",
        "x-api-key": session.apiKey,
        Accept: "application/json",
      },
      body: "grant_type=client_credentials&scope=accounts",
    });
    if (!res.ok) {
      throw new Error(`token request failed (${res.status})`);
    }
    const data = (await res.json()) as { access_token: string; expires_in?: number };
    cached = {
      value: data.access_token,
      expiresAt: Date.now() + ((data.expires_in ?? 1800) - 60) * 1000,
    };
    return cached.value;
  }

  async function forward(path: string): Promise<unknown> {
    const token = await getToken();
    const res = await fetch(`${hosts().apiBase}${path}`, {
      headers: { Authorization: `Bearer ${token}`, "x-api-key": session.apiKey, Accept: "application/json" },
    });
    if (!res.ok) throw new Error(`investec ${path} failed (${res.status})`);
    return res.json();
  }

  const handler: Connect.NextHandleFunction = (req, res, next) => {
    const url = req.url ?? "";
    if (!url.startsWith("/api/investec/")) return next();

    void (async (r: IncomingMessage, out: ServerResponse) => {
      const send = (status: number, body: unknown) => {
        out.statusCode = status;
        out.setHeader("Content-Type", "application/json");
        out.end(JSON.stringify(body));
      };
      const sub = url.replace("/api/investec", "");

      // Attach a user's own keys for this session.
      if (sub === "/credentials" && r.method === "POST") {
        try {
          const body = JSON.parse((await readBody(r)) || "{}");
          const clientId = String(body.clientId ?? "").trim();
          const secret = String(body.secret ?? "").trim();
          const apiKey = String(body.apiKey ?? "").trim();
          const environment = body.environment === "production" ? "production" : "sandbox";
          if (!clientId || !secret || !apiKey) {
            return send(400, { error: "incomplete", message: "clientId, secret and apiKey are required." });
          }
          session = { clientId, secret, apiKey, environment };
          cached = null;
          // Validate immediately so the UI can report a bad key clearly.
          await getToken();
          return send(200, { ok: true, environment });
        } catch (err) {
          session = { ...defaults }; // fall back so the app still works
          cached = null;
          return send(401, { error: "invalid-credentials", message: (err as Error).message });
        }
      }

      // Revert to the default (sandbox) session and forget the user's keys.
      if (sub === "/disconnect" && r.method === "POST") {
        session = { ...defaults };
        cached = null;
        return send(200, { ok: true });
      }

      if (!session.secret || !session.apiKey) {
        return send(503, {
          error: "no-credentials",
          message: "No Investec credentials set. Attach your API key or copy .env.example to .env.",
        });
      }

      try {
        if (sub === "/accounts") return send(200, await forward("/accounts"));
        const balance = sub.match(/^\/accounts\/([^/]+)\/balance$/);
        if (balance) return send(200, await forward(`/accounts/${balance[1]}/balance`));
        const tx = sub.match(/^\/accounts\/([^/]+)\/transactions$/);
        if (tx) return send(200, await forward(`/accounts/${tx[1]}/transactions`));
        return send(404, { error: "unknown-route", route: sub });
      } catch (err) {
        return send(502, { error: "upstream", message: (err as Error).message });
      }
    })(req, res);
  };

  return {
    name: "investec-proxy",
    configureServer(server) {
      server.middlewares.use(handler);
    },
  };
}

export default defineConfig(({ mode }) => {
  // Credentials are read here at server start and held server-side only.
  const env = loadEnv(mode, process.cwd(), "");
  return {
    plugins: [react(), investecProxy(env)],
    clearScreen: false,
    server: { port: 5173, strictPort: false },
  };
});
