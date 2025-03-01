-- task_manager.lua
local cjson = require "cjson"
local xxl_job = require("resty.xxl_job.executor")

local ngx = ngx
local timer = ngx.timer.at
local shared = ngx.shared.task_store
local spawn = ngx.thread.spawn

local _M = {
    _VERSION = '1.0.0',
    max_running = 10,  -- 最大并发数
    running = {},      -- 正在运行的任务
    pending = {},      -- 等待队列
    task_id = 0        -- 任务ID计数器
}

-- 初始化共享存储
if not shared then
    ngx.log(ngx.ERR, "需要在nginx.conf中声明共享内存：lua_shared_dict task_store 10m;")
end


-- 执行任务包装器
function _M.task_wrapper(_, args)
    local ok, err = spawn(xxl_job.run_handler, args)

    local task_id = args.jobId
    -- 清理运行记录
    shared:delete("running:"..task_id)
    _M.running[task_id] = nil

    -- 触发下一个任务
    _M.check_pending()

    if not ok then
        ngx.log(ngx.ERR, "Task failed: ", task_id, " error: ", err)
    end
end

-- 检查并触发等待任务
function _M.check_pending()
    local current = shared:get("running_count") or 0
    while current < _M.max_running and #_M.pending > 0 do
        current = current + 1
        shared:incr("running_count", 1)

        local next_task = table.remove(_M.pending, 1)
        local task_id = next_task.args.jobId
        -- 记录运行状态
        _M.running[task_id] = {
            co = timer(0, _M.task_wrapper, next_task.args),
            args = next_task.args,
            create_time = ngx.now()
        }
        shared:set("running:"..task_id, cjson.encode(_M.running[task_id]))
    end
end

-- 添加新任务
function _M.add_task(args)
    local task = {
        args = args,
        add_time = ngx.now()
    }

    table.insert(_M.pending, task)
    shared:lpush("pending", cjson.encode(task))
    _M.check_pending()
    return true
end

-- 终止任务
function _M.kill_task(task_id)
    -- 处理等待任务
    for i = #_M.pending, 1, -1 do
        if _M.pending[i].id == task_id then
            table.remove(_M.pending, i)
            shared:lrem("pending", i)
            return true
        end
    end

    -- 处理运行中任务
    if _M.running[task_id] then
        local ok, err = pcall(ngx.thread.kill, _M.running[task_id].co)
        if ok then
            shared:delete("running:"..task_id)
            shared:decr("running_count", 1)
            _M.running[task_id] = nil
            return true
        end
        return false, err
    end

    return false, "Task not found"
end

-- 获取任务状态
function _M.get_status(task_id)
    if _M.running[task_id] then
        return "RUNNING", _M.running[task_id]
    end

    for _, task in ipairs(_M.pending) do
        if task.id == task_id then
            return "PENDING", task
        end
    end

    return "NOT_FOUND"
end

-- 恢复共享内存中的状态（在init_worker阶段调用）
function _M.restore_state()
    -- 恢复运行中的任务数
    local running = shared:get_keys(0)
    local count = 0
    for _, key in ipairs(running) do
        if key:match("^running:") then
            count = count + 1
        end
    end
    shared:set("running_count", count)
end

-- 获取监控指标
function _M.get_metrics()
    return {
        running = shared:get("running_count") or 0,
        pending = shared:llen("pending"),
        max = _M.max_running
    }
end

-- 动态配置
function _M.set_max_concurrency(new_max)
    _M.max_running = tonumber(new_max) or 10
    _M.check_pending()
end

--完善日志记录
function _M.log_event(event_type, task_id)
    local log_entry = string.format("[%s] %s %s %s",
        ngx.localtime(),
        event_type,
        task_id,
        ngx.var.remote_addr
    )
    shared:rpush("task_logs", log_entry)
end

return _M