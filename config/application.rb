# -*- coding: utf-8 -*-
require "sinatra"
require "sinatra/multi_route"
require "sinatra/reloader"

# --------------------------------
class MLLikeServiceWeb < Sinatra::Base
  register Sinatra::MultiRoute
  register Sinatra::Reloader
  
  set :public_dir, File.expand_path("../../public", __FILE__)
  set :views, File.expand_path("../../app/views", __FILE__)

  Tilt.register Tilt::ERBTemplate, 'html.erb'
  
  # --------------------------------
  logpath = File.expand_path("../../log", __FILE__)  
  Dir.mkdir(logpath) unless Dir.exist?(logpath)
  @@logger = Logger.new(logpath + "/access.log", 2, 1024 * 1024)
  @@logger.level = Logger::DEBUG
  @@logger.formatter = proc{|s, d, p, m| "#{d.to_s[0, 19]} #{p}[#{$$}] #{m}\n"}

  @@logger.info("Start ML Like Service.")
  def logger; @@logger; end
  def log(msg)
    puts "#{Time.now.to_s[0, 19]} [#{$$}] #{msg}"
  end

  #def root_path; return "/mllikeservice"; end # for nginx :p
  def root_path; return ""; end
  
  # --------------------------------
  varpath = File.expand_path("../../var", __FILE__)
  Dir.mkdir(varpath) unless Dir.exist?(varpath)
  tmppath = File.expand_path("../../tmp", __FILE__)
  Dir.mkdir(tmppath) unless Dir.exist?(tmppath)
  datpath = File.expand_path("../../data", __FILE__)
  Dir.mkdir(datpath) unless Dir.exist?(datpath)

  # --------------------------------
  # use session
  use Rack::Session::Cookie, :key => "sinatra.session.mllikeservice",
                             :expire_after => 60 * 60 * 24 * 3,
                             :secret => Digest::SHA256.hexdigest("T2n*$8~E")

  # --------------------------------
  # authentication
  AdminUser = "admin"
  USERS = { AdminUser => "admin" }
  
  # basic authenticate
  use Rack::Auth::Basic, "ML Like Service Web" do |username, password|
    USERS[username] == password
  end
                                   
end

