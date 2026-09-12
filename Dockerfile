FROM prawee/strapi:1.1.0

# ติดตั้ง Nodemailer provider ไว้ใน Image ตั้งแต่ขั้นตอน Build ครั้งเดียวจบ
RUN yarn add @strapi/provider-email-nodemailer --ignore-engines