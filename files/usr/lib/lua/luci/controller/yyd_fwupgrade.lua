-- 固件在线更新 LuCI 控制器
-- 菜单: 系统 -> 固件在线更新
-- 依赖 luci-compat (传统 controller/template API)

module("luci.controller.yyd_fwupgrade", package.seeall)

function index()
    entry({"admin", "system", "yyd_fwupgrade"},
        template("yyd_fwupgrade/main"), "固件在线更新", 80).dependent = false
    entry({"admin", "system", "yyd_fwupgrade", "check"},
        call("action_check")).leaf = true
    entry({"admin", "system", "yyd_fwupgrade", "flash"},
        call("action_flash")).leaf = true
    entry({"admin", "system", "yyd_fwupgrade", "progress"},
        call("action_progress")).leaf = true
end

function action_check()
    local out = luci.sys.exec("/usr/bin/fw-upgrade --check-json 2>/dev/null")
    luci.http.prepare_content("application/json")
    luci.http.write(#out > 0 and out or '{"ok":false}')
end

function action_flash()
    local channel = luci.http.formvalue("channel") or "auto"
    if channel ~= "auto" and channel ~= "ghfast"
        and channel ~= "ghproxy" and channel ~= "native" then
        channel = "auto"
    end
    -- 脱离终端后台执行，避免 uhttpd 请求结束时被回收
    luci.sys.call("( /usr/bin/fw-upgrade --flash " .. channel .. " >/tmp/fw-upgrade.log 2>&1 & )")
    luci.http.prepare_content("application/json")
    luci.http.write('{"ok":true}')
end

function action_progress()
    local f = io.open("/tmp/fw-upgrade.progress", "r")
    luci.http.prepare_content("application/json")
    if f then
        local c = f:read("*a")
        f:close()
        luci.http.write(#c > 0 and c or '{"stage":"idle","percent":0,"detail":""}')
    else
        luci.http.write('{"stage":"idle","percent":0,"detail":""}')
    end
end
