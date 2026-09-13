const RateLimit = require("koa2-ratelimit").RateLimit;

const AUTH_PATHS = [
  "/api/auth/local",
  "/api/auth/local/register",
  "/api/auth/forgot-password",
  "/api/auth/reset-password",
  "/api/auth/change-password",
];

module.exports = (config, { strapi }) => {
  const { enabled = true, max = 5, intervalMin = 1 } = config || {};
  const limiter = RateLimit.middleware({
    interval: { min: intervalMin },
    delayAfter: 0,
    timeWait: 0,
    max,
    prefixKey: "public-auth",
  });
  return async (ctx, next) => {
    if (enabled && AUTH_PATHS.includes(ctx.request.path)) {
      return limiter(ctx, next);
    }
    return next();
  };
};