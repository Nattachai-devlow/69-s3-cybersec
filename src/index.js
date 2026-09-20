"use strict";

module.exports = {
  register(/*{ strapi }*/) {},

  async bootstrap({ strapi }) {
    // กันทุก instance ที่รันจาก repo นี้ เปิดให้บุคคลทั่วไปสมัครสมาชิก
    // allow_register ถูกเก็บใน DB (strapi_core_store_settings) ซึ่ง git เอาไปด้วยไม่ได้
    // จึงสั่งปิดทุกครั้งที่ Strapi boot ผ่าน plugin store
    try {
      const store = strapi.store({
        type: "plugin",
        name: "users-permissions",
      });
      const advanced = (await store.get({ key: "advanced" })) || {};
      if (advanced.allow_register !== false) {
        advanced.allow_register = false;
        await store.set({ key: "advanced", value: advanced });
        strapi.log.warn("[bootstrap] allow_register -> false (register disabled)");
      }
    } catch (err) {
      strapi.log.warn(`[bootstrap] failed to enforce allow_register=false: ${err.message}`);
    }
  },
};