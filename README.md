# OpenResty XXL-JOB 客户端插件使用文档

## 概述
本插件用于在OpenResty中集成XXL-JOB分布式任务调度框架的执行器功能，支持通过Lua脚本快速注册和执行定时任务。

---

## 初始化配置

参数配置项

```lua
    -- xxl_job配置
	xxl_job = {
        admin_address = "http://127.0.0.1:8081/xxl-job-admin",
        app_name = "openresty-executor",
		host = "127.0.0.1",
        port = 8888,
        access_token = "default_token",
        username = "admin",
        password = "123456",
        executor_address = ""
    }
```

```nginx
    #任务存储共享内存
    lua_shared_dict task_store 1m;
    #初始化
    init_by_lua_file ./app/init.lua;
    #定时执行的任务
    init_worker_by_lua_file ./app/vsws/mq_transmit.lua;
```

init.lua
```lua
    local xxl_job = require("resty.xxl_job.executor")
    local handlers = require("app.services.xxl_job_handlers")
    local my_config = require("app.config.".. config:get("config"))
    xxl_job.setup(my_config.xxl_job)
    for k,v in pairs(handlers) do
        xxl_job.register_handler(k,v)
    end
```

xxl_job_handlers.lua
```lua
    return {
    ["easyHandler"] = function (x)
        print("简单测试:" .. x)
    end
}
```

mq_transmit.lua
```lua
    local xxl_job = require("resty.xxl_job.executor")
    --执行器注册xxl-job
	local ok, err = ngx.timer.at(DELAY_TIME_NUM,xxl_job.init)
```

router_config.lua
```lua
    xxl_job = {
        { uri = "/xxl_job",    router = "resty.xxl_job.route"}
    }
```

## 功能示例

```lua
    local xxl_job = require("resty.xxl_job.executor")
    -- 新增任务
    local add_job_info = {
        desc = "测试增加任务1",
        author = "zdp",
        cron = "0 0 8 * * ?",
        handler = "easyHandler",
        params = "{\"a\":1}"
    }
    xxl_job.add_job(add_job_info)
    -- 修改任务
    local update_job_info = {
        id = 1,
        desc = "测试增加任务1",
        author = "zdp",
        cron = "0 0 8 * * ?",
        handler = "easyHandler",
        params = "{\"a\":1}"
    }
    xxl_job.update_job(update_job_info)
    -- 删除任务
    local job_id = 1
    xxl_job.remove_job(job_id)
    -- 启动任务
    local job_id = 1
    xxl_job.start_job(job_id)
    -- 停止任务
    local job_id = 1
    xxl_job.stop_job(job_id)
    -- 立即触发任务
    local trigger_job_info = {
        id = 1,
        params = "{\"a\":1}"
    }
    xxl_job.trigger_job(trigger_job_info)
    -- 获取任务列表
    local params = {
        start = 0,
        length = 20
    }
    xxl_job.list_jobs(params)
```