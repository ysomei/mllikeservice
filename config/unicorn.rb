# -*- coding: utf-8 -*-

application_name = "mllikeservice"
apname = application_name.gsub("-", "_")

# -- running process number
case ENV['RACK_ENV']
when "production"
  worker_processes 2
else
  worker_processes 2
end

# -- application path
apppath = File.expand_path("./")
working_directory apppath

timeout 120

# -- temporary directory
tmppath = File.expand_path("../../tmp", __FILE__)
Dir.mkdir(tmppath) unless Dir.exist?(tmppath)

listen tmppath + "/unicorn_#{apname}.sock", :backlog => 64
pidfile = tmppath + "/#{apname}.pid"
pid pidfile

# -- log directory
logpath = File.expand_path("../../log", __FILE__)
Dir.mkdir(logpath) unless Dir.exist?(logpath)

logfilename = "development.log"
logfilename = "production.log" if ENV['RACK_ENV'].to_s == "production"
stderr_path logpath + "/#{logfilename}"
stdout_path logpath + "/#{logfilename}"

# ----------------------------------------------------------------------------
# start interval process
require_relative "./intervalprocess"
inp = IntervalProcess.new(pidfile)
_interval_thread = Thread.new(inp) do |inps|
  inps.run
end

