module.exports = [
  {
    resolve: "/opt/app/middlewares/audit-log.js",
    config: {},
  },
  "strapi::logger",
  "strapi::errors",
  "strapi::security",
  {
    name: "strapi::cors",
    config: {
      // อนุญาตเฉพาะ origin ที่รู้จัก (เพิ่ม origin ของ front-end เองด้วย)
      origin: [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:5173",
        "http://127.0.0.1:5173",
      ],
      methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"],
      headers: ["Content-Type", "Authorization", "Origin", "Accept"],
      credentials: true,
      keepHeadersOnError: true,
    },
  },
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