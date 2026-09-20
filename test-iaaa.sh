#!/usr/bin/env bash
# =====================================================================
# test-iaaa.sh — ตรวจความแข็งแรง Password Service ตามมาตรฐาน IAAA
#   Identification / Authentication / Authorization / Accountability
#
# วิธีใช้:
#   chmod +x test-iaaa.sh
#   ./test-iaaa.sh          # ต้องมี secret.env + .env อยู่ข้างๆ (gitignored)
#
# หมายเหตุ:
#   1. หลัง test หัวข้อ rate-limit (T9) ระบบจะ lock IP ~1 นาที
#      รันครั้งเดียวแล้วดูผล หรือเว้น >1 นาทีหากรันซ้ำ
#   2. ต้องรัน app จาก repo นี้ เพื่อให้ bootstrap ปิด register ทำงาน
#   3. ไฟล์นี้ไม่มี secret จริง ใส่ไว้ได้ปลอดภัย
# =====================================================================

BASE_URL="${BASE_URL:-http://127.0.0.1:8037}"
APP_CONTAINER="${APP_CONTAINER:-69-s3-app}"
MAILHOG_API="${MAILHOG_API:-http://127.0.0.1:8025/api/v2/messages}"

PASS=0
FAIL=0
NTEST=0
ok()   { PASS=$((PASS+1)); printf "[PASS] %s\n" "$1"; }
bad()  { FAIL=$((FAIL+1)); printf "[FAIL] %s\n" "$1"; }
step() { NTEST=$((NTEST+1)); printf "\n--- T%d: %s ---\n" "$NTEST" "$1"; }

# ---------- โหลด credential จากไฟล์ gitignored (กันปัญหา CRLF) ----------
set -a
[ -f secret.env ] && . <(tr -d '\r' < secret.env)
[ -f .env ] && . <(tr -d '\r' < .env)
set +a
if [ -z "${ADMIN_PASSWORD:-}" ] || [ -z "${USER_PASSWORD:-}" ]; then
  echo "ERROR: ต้องมีไฟล์ secret.env (มี ADMIN_PASSWORD/USER_PASSWORD) ข้างสคริปต์"; exit 1
fi
if [ -z "${POSTGRES_PASSWORD:-}" ]; then
  echo "ERROR: ต้องมีไฟล์ .env (มี POSTGRES_PASSWORD) เพื่อตรวจ hash ใน DB"; exit 1
fi
PU="${POSTGRES_USER:-nattachai@rmutp.ac.th}"
PD="${POSTGRES_DB:-nattachai}"

# =====================================================================
# I — Identification
# =====================================================================

step "I1: ปิดสมัครสมาชิกผู้ใช้ทั่วไป (register ต้อง 400 + 'disabled')"
code=$(curl -s -o /tmp/t1.json -w "%{http_code}" -X POST "$BASE_URL/api/auth/local/register" \
  -H 'Content-Type: application/json' \
  -d '{"username":"iaaa_test","email":"iaaa_test@x.com","password":"12345678"}')
if [ "$code" = "400" ] && grep -q "disabled" /tmp/t1.json; then
  ok "register ถูกปิด (400): $(grep -o 'Register action is currently disabled' /tmp/t1.json)"
else bad "register ควรได้ 400+disabled แต่ได้ $code"; fi

step "I2: ปิดสมัครแอดมิน (admin/register-admin ต้อง 400)"
code=$(curl -s -o /tmp/t2.json -w "%{http_code}" -X POST "$BASE_URL/admin/register-admin" \
  -H 'Content-Type: application/json' \
  -d '{"firstname":"x","lastname":"x","email":"x@x.com","password":"abc"}')
if [ "$code" = "400" ]; then ok "admin register ปิด (400 ValidationError)"
else bad "admin register ควรได้ 400 แต่ได้ $code"; fi

step "I3: ตรวจ unique_email (ค่าใน DB)"
DBV=$(docker exec -i -e PGUSER="$PU" -e PGPW="$POSTGRES_PASSWORD" -e PGDB="$PD" \
  "$APP_CONTAINER" node - <<'EOF'
const { Client } = require("pg");
const c=new Client({host:"db",port:5432,user:process.env.PGUSER,password:process.env.PGPW,database:process.env.PGDB});
c.connect().then(async()=>{
  const r=await c.query("SELECT value::jsonb->>'unique_email' v FROM strapi_core_store_settings WHERE key=$$plugin_users-permissions_advanced$$",[]);
  console.log(r.rows[0]?r.rows[0].v:"");
  await c.end();
}).catch(e=>{console.log("ERR");process.exit(1)});
EOF
)
if [ "$DBV" = "true" ]; then ok "unique_email = true (ห้าม email ซ้ำ)"
else bad "unique_email ควรเป็น true แต่ได้: $DBV"; fi

# =====================================================================
# A — Authentication
# =====================================================================

step "A1: login รหัสถูกต้อง ต้อง 200 + ได้ jwt"
resp=$(curl -s -X POST "$BASE_URL/api/auth/local" -H 'Content-Type: application/json' \
  -d "{\"identifier\":\"${USER_EMAIL:-ido2@gmail.com}\",\"password\":\"$USER_PASSWORD\"}")
if echo "$resp" | grep -q '"jwt"'; then ok "login สำเร็จ + ได้ jwt"
else bad "login ควรได้ jwt แต่ได้: $(echo "$resp" | head -c 120)"; fi

step "A2: login รหัสผิด ต้อง 400 (ไม่เปิดเผยว่า user มีอยู่)"
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/auth/local" \
  -H 'Content-Type: application/json' \
  -d "{\"identifier\":\"${USER_EMAIL:-ido2@gmail.com}\",\"password\":\"WRONG!\"}")
if [ "$code" = "400" ]; then ok "login ผิด -> 400"
else bad "login ผิดควรได้ 400 แต่ได้ $code"; fi

step "A3: forgot-password ต้อง 200 (ส่งเมล reset)"
code=$(curl -s -o /tmp/t4.json -w "%{http_code}" -X POST "$BASE_URL/api/auth/forgot-password" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${USER_EMAIL:-ido2@gmail.com}\"}")
if [ "$code" = "200" ]; then ok "forgot-password -> 200"
else bad "forgot ควรได้ 200 แต่ได้ $code: $(cat /tmp/t4.json)"; fi

step "A4: ทุก password เก็บเป็น bcrypt (\$2a\$10\$ ความยาว 60)"
DBRES=$(docker exec -i -e PGUSER="$PU" -e PGPW="$POSTGRES_PASSWORD" -e PGDB="$PD" \
  "$APP_CONTAINER" node - <<'EOF'
const { Client } = require("pg");
const c=new Client({host:"db",port:5432,user:process.env.PGUSER,password:process.env.PGPW,database:process.env.PGDB});
c.connect().then(async()=>{
  const u=await c.query("SELECT password FROM up_users",[]);
  const a=await c.query("SELECT password FROM admin_users",[]);
  const all=[...u.rows,...a.rows];
  const bad=all.filter(r=>!/^\$2[abxy]\$10\$/.test(r.password)||r.password.length!==60);
  console.log(bad.length?("BAD_COUNT="+bad.length):("OK count="+all.length));
  await c.end();
}).catch(e=>{console.log("ERR");process.exit(1)});
EOF
)
if [ "$(echo "$DBRES" | grep -c '^OK')" = "1" ]; then ok "ทุกบัญชี bcrypt: $DBRES"
else bad "BCrypt ผิดปกติ: $DBRES"; fi

step "A5: token ปลอม/เก่า ใช้ไม่ได้ (ต้อง 401)"
code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/admin/users/me" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJpZCI6MX0.aaaaaaaaaaaaaaaaaaaaaa")
if [ "$code" = "401" ]; then ok "token ปลอม -> 401"
else bad "token ปลอมควรได้ 401 แต่ได้ $code"; fi

# =====================================================================
# A — Authorization
# =====================================================================

step "A6: token ผู้ใช้ ใช้เข้า admin API ไม่ได้ (ต้อง 401)"
UT=$(curl -s -X POST "$BASE_URL/api/auth/local" -H 'Content-Type: application/json' \
  -d "{\"identifier\":\"${USER_EMAIL:-ido2@gmail.com}\",\"password\":\"$USER_PASSWORD\"}" \
  | grep -o '"jwt":"[^"]*"' | cut -d'"' -f4)
code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/admin/users/me" -H "Authorization: Bearer $UT")
if [ "$code" = "401" ]; then ok "user token -> /admin/users/me = 401"
else bad "ควร 401 แต่ได้ $code"; fi

step "A7: CORS — origin ต้องห้ามถูกบล็อก"
hdr=$(curl -s -I -X OPTIONS "$BASE_URL/api/auth/local" \
  -H "Origin: https://evil-example.com" -H "Access-Control-Request-Method: POST" \
  | grep -i "access-control-allow-origin" || true)
if [ -z "$hdr" ]; then ok "evil origin -> ไม่มี header ACAO (browser บล็อก)"
else bad "evil origin ยังได้ header: $hdr"; fi

step "A8: CORS — origin ที่อนุญาตผ่าน"
hdr=$(curl -s -I -X OPTIONS "$BASE_URL/api/auth/local" \
  -H "Origin: http://localhost:3000" -H "Access-Control-Request-Method: POST" \
  | grep -i "access-control-allow-origin" || true)
if [ -n "$hdr" ]; then ok "localhost:3000 -> $hdr"
else bad "localhost:3000 ควรผ่าน CORS"; fi

# =====================================================================
# A — Accountability
# =====================================================================

step "A9: rate limit กันลองรหัสซ้ำ (burst ต้องเจอ 429)"
codes=""
for i in 1 2 3 4 5 6; do
  codes="$codes $(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/auth/local" \
    -H 'Content-Type: application/json' \
    -d "{\"identifier\":\"${USER_EMAIL:-ido2@gmail.com}\",\"password\":\"wrong\"}")"
done
if echo "$codes" | grep -q "429"; then ok "burst: $codes"
else bad "burst ควรมี 429 แต่ได้: $codes"; fi

step "A10: audit.log มีร่องรอยเหตุการณ์ (register + 429)"
logfile="${AUDIT_LOG:-./logs/audit.log}"
[ -f "$logfile" ] || logfile='/mnt/c/Users/ADMIN/69-s3-cybersec/logs/audit.log'
entries=$(wc -l < "$logfile" 2>/dev/null || echo 0)
reg_cnt=$(grep -c '"/api/auth/local/register"' "$logfile" 2>/dev/null || echo 0)
rl_cnt=$(grep -c '"status":429' "$logfile" 2>/dev/null || echo 0)
if [ "${reg_cnt:-0}" -ge 1 ] && [ "${rl_cnt:-0}" -ge 1 ]; then
  ok "audit.log: $entries บรรทัด (register=$reg_cnt, 429=$rl_cnt)"
else
  bad "audit.log: $entries บรรทัด (register=$reg_cnt, 429=$rl_cnt) — path: $logfile"
fi

step "A11: จดหมาย reset password ส่งจริง (Mailhog)"
mj=$(curl -s "$MAILHOG_API?limit=1" 2>/dev/null | grep -o '"Subject"' | head -1)
if [ -n "$mj" ]; then ok "Mailhog มีเมล reset อยู่"
else bad "ไม่พบเมลที่ $MAILHOG_API"; fi

# =====================================================================
printf "\n=================================\n"
printf "ผลรวม IAAA: PASS=%d FAIL=%d (เต็ม %d หัวข้อ)\n" "$PASS" "$FAIL" "$NTEST"
printf "คะแนนรวม = %d%%\n" "$(( PASS * 100 / NTEST ))"
echo "================================="