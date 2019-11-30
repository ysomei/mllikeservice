# -*- coding: utf-8 -*-
require "bundler/setup"
require "yaml"
require "erb"
require "json"
require "net/http"
require "uri"
require "cgi"
require "logger"
require "open3"
require "date"

require "mail"

# set timezone
#Time.zone = "Tokyo"

# ----------------------------------------------------------------------------
# load application.rb and more (in config folder :p)
require_relative "application.rb"
require_relative "ext_string.rb"

# ----------------------------------------------------------------------------
# load initializers
init_path = File.expand_path("../initializers", __FILE__)
Dir.glob(init_path + "/*.rb").each do |filename|
  fname = filename.gsub(init_path + "/", "")
  eval("require '#{filename}'")
end

# ----------------------------------------------------------------------------
# database configuration
dbruby = []
dbruby.each do |dbr|
  require_relative "../app/models/#{dbr}"
end
# load app/models/*.rb
models_path = File.expand_path("../../app/models", __FILE__)
Dir.glob(models_path + "/*.rb").each do |filename|
  fname = filename.gsub(models_path + "/", "")
  next if dbruby.include?(fname)
  eval("require '#{filename}'")
end

# ----------------------------------------------------------------------------
# require main controller/actions
require_relative "../app/controllers/main.rb"

# ----------------------------------------------------------------------------
# load app/helpers/*.rb
helper_path = File.expand_path("../../app/helpers", __FILE__)
Dir.glob(helper_path + "/*.rb").each do |filename|
  eval("require '#{filename}'")
end

# ----------------------------------------------------------------------------
# load app/controllers/*.rb
app_path = File.expand_path("../../app/controllers", __FILE__)
Dir.glob(app_path + "/*.rb").each do |filename|
  next if filename =~ /main\.rb/
  eval("require '#{filename}'")
end

