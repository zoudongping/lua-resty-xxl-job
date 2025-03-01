rockspec_format = "3.0"
package = "lua-resty-xxl-job"
version = "0.1-1"
source = {
   url = "git+https://github.com/zoudongping/lua-resty-xxl-job.git"
}
description = {
   detailed = "lua-resty-xxl-job - Lua XXL-JOB client driver for the ngx_lua based",
   homepage = "https://github.com/zoudongping/lua-resty-xxl-job",
   license = "BSD License 2.0",
   labels = { "XXL-JOB", "OpenResty", "Nginx" }
}
build = {
   type = "builtin",
   modules = {
      ["resty.xxl_job.executor"] = "lib/resty/xxl_job/executor.lua",
      ["resty.xxl_job.route"] = "lib/resty/xxl_job/route.lua",
      ["resty.xxl_job.schema"] = "lib/resty/xxl_job/schema.lua",
      ["resty.xxl_job.task"] = "lib/resty/xxl_job/task.lua"
   }
}