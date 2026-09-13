module.exports = ({ env }) => ({
  auth: {
    secret: env("ADMIN_JWT_SECRET"),
  },
  apiToken: {
    salt: env("API_TOKEN_SALT"),
  },
  transfer: {
    token: {
      salt: env("TRANSFER_TOKEN_SALT"),
    },
  },
  // ปิดไม่ให้ลงทะเบียน Admin ใหม่หากมี Super Admin อยู่แล้ว
  registration: {
    enabled: false,
  },
  rateLimit: {
    enabled: true,
    interval: 60000, // 1 นาที
    max: 5, // ลองผิดได้ไม่เกิน 5 ครั้ง ต่อ 1 นาที
  },
});
