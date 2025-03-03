local http = require("resty.http")
local cjson = require("cjson")

local timer = ngx.timer
local time = ngx.time
local update_time = ngx.update_time
local config = ngx.shared.config
local log = ngx.log
local ERR = ngx.ERR
local DEBUG = ngx.DEBUG

local xxl_job = {
    _VERSION = "1.0.0",
    config = {
        admin_address = "",
        app_name = "",
        port = 9999,
        access_token = "",
        username = "",
        password = "",
        executor_address = "",
        executor_id = nil
    },
    handlers = {},
    run_lists = {},
    auth_cookie = "",
    last_login = 0
}

-- HTTP客户端工具方法
local function http_request(method, url, body, headers)
    local httpc = http.new()
    local res, err = httpc:request_uri(url, {
        method = method,
        body = body,
        headers = headers,
        ssl_verify = false
    })

    if not res then
        ngx.log(ngx.ERR, "HTTP request failed: ", err)
        return nil, err
    end

    -- local data = cjson.decode(res.body)
    return res, nil
end

-- 初始化配置
function xxl_job.setup(cfg)
    for k, v in pairs(cfg) do
        xxl_job.config[k] = v
    end
    xxl_job.config.executor_address = "http://"..xxl_job.config.host..":"..xxl_job.config.port .. "/xxl_job"
end

-- 登录认证
function xxl_job.login()
    local httpc = http.new()
    local res, err = httpc:request_uri(xxl_job.config.admin_address .. "/login", {
        method = "POST",
        body = "userName=" .. xxl_job.config.username .. "&password=" .. xxl_job.config.password,
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
        }
    })

    log(ERR,"=======",cjson.encode(res.headers),res.status)
    if res and res.status == 200 then
        update_time()
        local now = time()
        config:set("xxl_job_auth_cookie", res.headers["Set-Cookie"])
        config:set("xxl_job_last_login", now)
        return res.headers["Set-Cookie"], now
    end

    log(DEBUG, "Login failed: ", err)
    return false
end

-- 带认证的HTTP请求
local function auth_request(method, path, body)
    local httpc = http.new()
    local url = xxl_job.config.admin_address .. path
    local auth_cookie = config:get("xxl_job_auth_cookie")
    local last_login = config:get("xxl_job_last_login")
    -- 自动处理登录状态
    log(DEBUG, "访问cookie：", auth_cookie, "时间:" , last_login)
    if not auth_cookie or time() - last_login > 3600 then
        auth_cookie, last_login = xxl_job.login()
        if not auth_cookie or not last_login then
            return nil, "Authentication failed"
        end
    end

    local headers = {
        ["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8",
        ["Cookie"] = auth_cookie,
        ["XXL-JOB-ACCESS-TOKEN"] = xxl_job.config.access_token
    }

    local req_data = ""
    for k,v in pairs(body or {}) do
        if req_data ~= "" then
            req_data = req_data .. "&"
        end
        req_data = req_data .. k .. "=" .. v
    end
    local res, err = httpc:request_uri(url, {
        method = method,
        body = req_data,
        headers = headers,
        ssl_verify = false
    })
    -- 处理认证过期
    if res and res.status == 401 then
        xxl_job.login()
        return auth_request(method, path, body)
    end

    if not res then
        log(DEBUG, "API request failed: ", err)
        return nil, err
    end

    return cjson.decode(res.body), res.status
end

-- 任务管理接口
-- 新增任务
function xxl_job.add_job(job_info)
    local executor_id = config:get("xxl_job_executor_id")
    return auth_request("POST", "/jobinfo/add", {
        jobGroup = executor_id,  -- 执行器ID
        jobDesc = job_info.desc,
        author = job_info.author,
        scheduleType = "CRON",
        scheduleConf = job_info.cron,
        glueType = "BEAN",
        executorHandler = job_info.handler,
        executorParam = job_info.params,
        executorRouteStrategy = "FIRST",
        misfireStrategy = "DO_NOTHING",
        executorBlockStrategy = "SERIAL_EXECUTION"
    })
end

-- 修改任务
function xxl_job.update_job(job_info)
    local executor_id = config:get("xxl_job_executor_id")
    return auth_request("POST", "/jobinfo/update", {
        id = job_info.id,
        jobGroup = executor_id,  -- 执行器ID
        jobDesc = job_info.desc,
        author = job_info.author,
        scheduleType = "CRON",
        scheduleConf = job_info.cron,
        glueType = "BEAN",
        executorHandler = job_info.handler,
        executorParam = job_info.params,
        executorRouteStrategy = "FIRST",
        misfireStrategy = "DO_NOTHING",
        executorBlockStrategy = "SERIAL_EXECUTION"
    })
end

function xxl_job.remove_job(job_id)
    return auth_request("POST", "/jobinfo/remove", {id = job_id})
end

function xxl_job.start_job(job_id)
    return auth_request("POST", "/jobinfo/start", {id = job_id})
end

function xxl_job.stop_job(job_id)
    return auth_request("POST", "/jobinfo/stop", {id = job_id})
end

-- 立即执行任务
function xxl_job.trigger_job(job_info)
    return auth_request("POST", "/jobinfo/trigger", {
        id = job_info.id,
        executorParam = job_info.params,
        addressList = ""
    })
end

-- 获取任务列表
function xxl_job.list_jobs(params)
    return auth_request("POST", "/jobinfo/pageList", {
        jobGroup = xxl_job.config.executor_id,  -- 执行器ID
        triggerStatus = -1,
        start = params.start or 0,
        length = params.length or 10
    })
end

-- 获取执行器列表
function xxl_job.job_groups(params)
    return auth_request("POST", "/jobgroup/pageList", {
        start = 0,
        length = 10,
        appname = xxl_job.config.app_name,
        title = params and params.title or nil
    })
end

-- 注册任务处理器
function xxl_job.register_handler(name, handler)
    xxl_job.handlers[name] = handler
end

-- 注册执行器到调度中心
function xxl_job.register_executor()
    local url = xxl_job.config.admin_address.."/api/registry"
    local body = {
        registryGroup = "EXECUTOR",
        registryKey = xxl_job.config.app_name,
        registryValue = xxl_job.config.executor_address
    }
    local resp,err =  http_request("POST", url, cjson.encode(body), {
        ["Content-Type"] = "application/json",
        ["Content-length"] = #cjson.encode(body),
        ["XXL-JOB-ACCESS-TOKEN"] = xxl_job.config.access_token
    })
    if not resp then
        return nil, "执行器注册失败：" .. err
    end
    local ok, data = pcall(cjson.decode, resp.body)
    if not ok then
        return nil, "执行器注册失败：" .. data
    end
    if data.code ~= 200 then
        return nil, "执行器注册失败：" .. resp.body
    end
    log(DEBUG, "执行器注册成功！")
    return true
end

-- 启动执行器（在init_worker阶段调用）
function xxl_job.init()
    -- 注册执行器
    local res, err = xxl_job.register_executor()
    if not res then
        log(ERR, "Executor registration failed: ", cjson.encode(res), err)
        return
    end
    if not xxl_job.config.executor_id then
        local job_groups,err = xxl_job.job_groups()
        if  job_groups then
            config:set("xxl_job_executor_id",job_groups.data[1].id)
            -- xxl_job.config.executor_id = job_groups.data[1].id
        end
    end
    timer.at(30, xxl_job.init)
end

-- 忙碌检测
function xxl_job.idleBeat(job_id)
    if xxl_job.run_lists[job_id] then
        return nil, "idleBeat任务[" .. job_id .. "]正在运行"
    end
    return true
end

-- 任务处理入口
function xxl_job.run_handler(params)
    local handler = xxl_job.handlers[params.executorHandler]
    local result = {
        logId = params.logId,
        logDateTime = params.logDateTime,
        code = 200,
        msg = "SUCCESS"
    }

    if handler then
        local ok, msg = pcall(handler, params.executorParams)
        if not ok then
            result.code = 500
            result.msg = msg
        end
    else
        result.code = 500
        result.msg = "Handler not found"
    end
    xxl_job.callback(result)
end

-- 任务执行完成回调结果
function xxl_job.callback(resp_data)
    local url = xxl_job.config.admin_address.."/api/callback"
    http_request("POST", url, cjson.encode({{
        logId = resp_data.logId,
        logDateTime = resp_data.logDateTime,
        handleCode = resp_data.code,
        handleMsg = resp_data.msg
    }}), {
        ["Content-Type"] = "application/json",
        ["XXL-JOB-ACCESS-TOKEN"] = xxl_job.config.access_token
    })
end

-- 关闭时注销执行器
function xxl_job.destroy()
    local url = xxl_job.config.admin_address.."/api/registryRemove"
    http_request("POST", url, cjson.encode({
        registryGroup = "EXECUTOR",
        registryKey = xxl_job.config.app_name,
        registryValue = xxl_job.config.executor_address
    }), {
        ["Content-Type"] = "application/json",
        ["XXL-JOB-ACCESS-TOKEN"] = xxl_job.config.access_token
    })
end

return xxl_job