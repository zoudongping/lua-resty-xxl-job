local ngx = ngx
local require = require

local ngx_time = ngx.time
local ngx_update_time = ngx.update_time
local spawn = ngx.thread.spawn

local cjson  = require("cjson")
local log    = require("app.libs.log")
local schema = require("app.libs.xxl_job.lib.resty.xxl_job.schema")
local lor = require("lor.index")
local xxl_job = require("app.libs.xxl_job.lib.resty.xxl_job.executor")
local task_util = require("app.libs.xxl_job.lib.resty.xxl_job.task")
local R   = lor:Router()

R:post("/run", function(req, res, next)
    local params = req.body

    -- 检查任务数据格式是否正确
    local ok, err = schema.validator(schema.run_req_def, params)
    if not ok then
        return res:json({
            code = 500,
            msg  = "数据格式错误：" .. err
        })
    end

    -- 检查任务是否存在
    local is_exists = false

    -- 检查任务是否存在
    if xxl_job.handlers[params.executorHandler] then
        is_exists = true
    end
    if not is_exists then
        return res:json({
            code = 500,
            msg  = "任务处理器没有注册"
        })
    end

    -- 增加任务
    task_util.add_task(params)
    -- 异步启动任务线程
    -- spawn(xxl_job.run_handler, params)

    -- 响应调度结果
    return res:json({
        code = 200,
        msg = ngx.null
    })

end)

R:post("/test", function (req, res, next)
    local body = req.body
    xxl_job.add_job(body)
    return res:json({
        code = 200,
        msg  = ngx.null
    })
end)

R:post("/kill", function(req, res, next)

    local jobId = req.body.jobId

    local result,err = task_util.kill_task(jobId)

    if not result or err then
        return res:json({
            code = 500,
            msg = err
        })
    end

    return res:json({
        code = 200,
        msg = "任务删除成功！"
    })
end)

R:post("/log", function(req, res, next)

    local params = req.body
    -- 检查日志数据格式是否正确
    local ok, err = schema.validator(schema.log_req_def, params)
    if not ok then
        return res:json({
            code = 500,
            msg  = "日志数据格式错误：" .. err,
            content = {
                fromLineNum = params.fromLineNum,
                toLineNum   = 0,
                logContent  = err,
                isEnd       = true
            }
        })
    end

    -- 检查是否有绑定日志处理
    local is_hander = false
    if is_hander then
        -- 使用绑定的日志处理器
    else
        -- 使用默认日志处理器
    end

    return

end)


R:post("/beat", function(req, res, next)

    log.debug("心跳检测到位")
    return res:json({
        code = 200,
        msg  = ngx.null
    })
end)


R:post("/idleBeat", function(req, res, next)
    local jobId = req.body.jobId

    if not jobId then
        return res:json({
            code = 500,
            msg  = "参数解析错误：" .. req.body_raw
        })
    end

    -- 检查是否存有任务列表中， 存在则返回 500， idelBeat任务【 jobId 】正在运行。
    local is_runlist_exists = false
    if is_runlist_exists then
        return res:json({
            code = 500,
            msg  = "idelBeat任务【 " .. jobId .. " 】正在运行。"
        })
    end

    -- 否则， 返回 200
    return res:json({
        code = 200,
        msg  = "idelBeat任务【 " .. jobId .. " 】已运行完。"
    })
end)


return R