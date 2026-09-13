module.exports = [
  {
    resolve: "/opt/app/middlewares/audit-log.js",
    config: {},
  },
  "strapi::logger",
  "strapi::errors",
  "strapi::security",
  "strapi::cors",
  "strapi::poweredBy",
  "strapi::query",
  "strapi::body",
  "strapi::session",
  "strapi::favicon",
  "strapi::public",
  {
    resolve: "/opt/app/middlewares/auth-rate-limit.js",
    config: {
      enabled: true,
      max: 5,
      intervalMin: 1,
    },
  },
];