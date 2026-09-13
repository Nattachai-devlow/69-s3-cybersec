module.exports = ({ env }) => ({
  email: {
    config: {
      provider: "nodemailer",
      providerOptions: {
        host: env("SMTP_HOST", "mailhog"),
        port: env.int("SMTP_PORT", 1025),
        secure: env.bool("SMTP_SECURE", false),
        auth: env("SMTP_USERNAME")
          ? { user: env("SMTP_USERNAME"), pass: env("SMTP_PASSWORD") }
          : undefined,
        tls: {
          requireTLS: env.bool("SMTP_REQUIRE_TLS", true),
          rejectUnauthorized: env.bool("SMTP_REJECT_UNAUTHORIZED", true),
        },
      },
      settings: {
        defaultFrom: env("SMTP_FROM", "no-reply@test.com"),
        defaultReplyTo: env("SMTP_FROM", "no-reply@test.com"),
      },
    },
  },
});