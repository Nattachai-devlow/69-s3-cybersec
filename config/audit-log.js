const fs = require("fs");
const path = require("path");

const AUTH_PATHS = [
  "/api/auth/local",
  "/api/auth/local/register",
  "/api/auth/forgot-password",
  "/api/auth/reset-password",
  "/api/auth/change-password",
];

const LOG_FILE = "/opt/app/logs/audit.log";

const safeBody = (body) => {
  if (!body || typeof body !== "object") return undefined;
  const out = {};
  if (body.email) out.email = body.email;
  if (body.identifier) out.identifier = body.identifier;
  if (body.username) out.username = body.username;
  return Object.keys(out).length ? out : undefined;
};

module.exports = (config, { strapi }) => {
  fs.mkdirSync(path.dirname(LOG_FILE), { recursive: true });
  return async (ctx, next) => {
    if (!AUTH_PATHS.includes(ctx.request.path)) {
      return next();
    }
    const startedAt = Date.now();
    let status;
    let error;
    try {
      await next();
      status = ctx.status;
    } catch (err) {
      error = err;
      status = err.status || err.statusCode || ctx.status || 500;
      throw err;
    } finally {
      const entry = {
        ts: new Date().toISOString(),
        method: ctx.request.method,
        path: ctx.request.path,
        status,
        agent: ctx.request.header["user-agent"] || "",
        ip: ctx.ip,
        body: safeBody(ctx.request.body),
        tookMs: Date.now() - startedAt,
        error: error ? (error.message || "error") : undefined,
      };
      fs.appendFile(LOG_FILE, `${JSON.stringify(entry)}\n`, (err) => {
        if (err) strapi.log.warn(`[audit-log] write failed: ${err.message}`);
      });
    }
  };
};