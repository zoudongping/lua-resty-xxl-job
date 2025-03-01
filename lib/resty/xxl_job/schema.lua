
local jsonschema = require("jsonschema")

local _M = { version = 0.1 }

local function validator( schema, data)
        --校验数据的完整性
        local validator = jsonschema.generate_validator(schema)
        local ok, err = validator(data)

        return ok, err
end


--通用响应
local res_def = {
    type = "object",
    properties = {
        code = {type = "integer"},
        msg  = {type = "string"},
    },
    required = {"code", "msg"},
}

--Registry 注册参数
local registry_def = {
    type = "object",
    properties = {
        registryGroup = { type = "string"},
        registryKey   = { type = "string"},
        registryValue = { type = "string"},
    },
    required = {
        "registryGroup", "registryKey" ,"registryValue"
    }
}

-- executeResult 任务执行结果 200 表示任务执行正常，500表示失败
local execute_result_def = res_def

local call_element_def = {
    type = "object",
    properties = {
        logId         = { type = "integer" },
        logDateTim    = { type = "integer" },
        executeResult = execute_result_def,
        handleCode    = { type = "integer" },
        handleMsg     = { type = "string"  },
    },
    required = {
        "logId", "logDateTim", "executeResult"
    }
}

-- RunReq 触发任务请求参数
local run_req_def = {
    type = "object",
    properties = {
        jobId           = { type = "integer"},
        executorHandler = { type = "string" },
        executorParams  = { type = "string"},
        executorBlockStrategy
                        = { type = "string" },
        executorTimeout = { type = "integer"},
        logId           = { type = "integer"},
        logDateTime     = { type = "integer"},
        glueType        = { type = "string" },
        glueSource      = { type = "string" },
        glueUpdatetime  = { type = "integer"},
        broadcastIndex  = { type = "integer"},
        broadcastTotal  = { type = "integer"}
    },
    required = {"jobId", "executorTimeout", "logId", "logDateTime", "glueType", "glueUpdatetime", "broadcastIndex", "broadcastTotal"}
}

--终止任务请求参数
local kill_req_def = {
    type = "object",
    properties = {
            jobId = { type = "integer"},
    },
    required = {"jobId"}
}

--忙碌检测请求参数
local idle_beat_req_def = kill_req_def

--LogReq 日志请求
local log_req_def = {
    type = "object",
    properties = {
            logDateTim  = { type = "integer"},
            logId       = { type = "integer"},
            fromLineNum = { type = "integer"},
    },
    required = {"jobId", "fromLineNum","logDateTim"}
}

-- LogResContent 日志响应内容
local log_res_content_def = {
    type = "object",
    properties = {
        fromLineNum = { type = "integer"},
        toLineNum   = { type = "integer"},
        logContent  = { type = "string" },
        isEnd       = { type = "boolean"},
    },
    required = {"fromLineNum","toLineNum","logContent","isEnd"}
}

-- LogRes 日志响应
local log_res_def = {
    type = "object",
    properties = {
        code = { type = "integer"},
        msg  = { type = "string" },
        content = log_res_content_def
    },
    required = {"code", "msg","content"}
}

_M.res_def = res_def

_M.registry_def        = registry_def
_M.execute_result_def  = execute_result_def
_M.call_element_def    = call_element_def

_M.run_req_def       = run_req_def
_M.kill_req_def      = kill_req_def
_M.idle_beat_req_def = idle_beat_req_def

_M.log_req_def = log_req_def
_M.log_res_def = log_res_def
_M.log_res_content_def = log_res_content_def

_M.validator = validator

return _M