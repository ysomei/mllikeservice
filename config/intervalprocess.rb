# -*- coding: utf-8 -*-
require "logger"
require "open3"
require "yaml"
require "date"

require_relative "./initializers/timestamp"

class IntervalProcess

  def initialize(pidfile)
    @pidfile = pidfile
    @eventups = { "00:00" => :loglotate, 
                  "**:00" => :hello, "**:30" => :hello,
                  "**:**" => :mailcheck_process
                }
    @bgprocesses = [ ]
    @isLoop = true
    
    # --------------------------------
    logpath = File.expand_path("../../log", __FILE__)  
    @logger = Logger.new(logpath + "/intervalprocess.log", 2, 1024 * 1024)
    @logger.level = Logger::DEBUG
    @logger.formatter = proc{|s, d, p, m| "#{d.to_s[0, 19]} #{p}[#{$$}] #{m}\n"}
    @logger.info("Start IntervalProcess Service")

    @homepath = "/Users" # Mac
    so, se, ss = Open3.capture3("uname")
    @homepath = "/home" if so =~ /Linux/
    so, se, ss = Open3.capture3("id -un")
    @currentuser = so.chomp
  end

  def run
    running_background_processes
    prevtime = Time.now.strftime("%H:%M")
    while @isLoop
      nowtime = Time.now.strftime("%H:%M")
      if nowtime != prevtime
        @logger.debug("check execute interval process")
        
        # scheduled execution!
        if @eventups.keys.include?(nowtime)
          doevent(@eventups[nowtime], "interval") # '#{nowtime}'")
        end
        
        # periodic execution!
        @eventups.keys.each do |ek|
          if ek == nowtime
            # nop :p <- doing upper line!
          else
            h, m = ek.split(":")
            bh = ""; bm = ""
            if h.length > 2
              bh = h[2..-1]
              h = h[0..1]
            end
            if m.length > 2
              bm = m[2..-1]
              m = m[0..1]
            end
            
            # hour check!
            isHour = false
            isHour = true if h =~ /^\*{1,2}$/ # hour -> '**' = every hour
            if h =~ /^\/\d{1,2}$/             # hour -> '/2' = par n hour
              eh = h.scan(/\d{1,2}/).first.to_i
              unless eh.zero?
                isHour = true if (nowtime[0, 2].to_i % eh).zero?
              end
            end
            isHour = true if h.to_i == nowtime[0, 2].to_i # hour -> '14' = 14
            
            # minutes check!
            isMinutes = false
            isMinutes = true if m =~ /^\*{1,2}$/ # min. -> '**' = every min.
            if m =~ /^\/\d{1,2}$/                # min. -> '/4' = par n min.
              em = m.scan(/\d{1,2}/).first.to_i
              unless em.zero?
                if bm.empty?
                  isMinutes = true if (nowtime[3, 2].to_i % em).zero?
                else
                  nt = nowtime[3, 2].to_i
                  nt = nt - bm[1..-1].to_i if bm[0] == "+"
                  nt = nt + (em - bm[1..-1].to_i) if bm[0] == "-"
                  isMinutes = true if (nt % em).zero?
                end
              end
            else
              isMinutes = true if m.to_i == nowtime[3, 2].to_i # min. '23' = 23
            end
            
            if isHour && isMinutes
              doevent(@eventups[ek], "periodic") # '#{ek}'")
            end
          end
        end
        prevtime = nowtime
      end
      sleep(0.2)
    end
  end

  def doevent(eventname, etype = "interval")
    @logger.info("find #{etype} process '#{eventname}'")
    t = Thread.new(etype, eventname) do |et, en|
      send(en)
      @logger.info("#{et} process '#{en}' done.")      
    end
    #t.join
  end
  
  # --------------------------------------------------------------------------
  def commandexecute(eventname, filename, cmd, targetdate = "", param = "")
    case filename.split(".")[-1]
    when "rb"
      rubypath = @homepath + "/#{@currentuser}/.rbenv/shims/"
      rubypath = "" unless Dir.exist?(rubypath)
      ruby = rubypath + "ruby"
      bundle = rubypath + "bundle exec"
      filepath = File.expand_path("../../bin", __FILE__)
      targetdate = " " + targetdate unless targetdate.empty?
      param = " " + param.to_s.strip unless param.to_s.strip.empty?
      so, se, ss = Open3.capture3("#{bundle} #{ruby} #{filepath}/#{filename} #{cmd}#{targetdate}#{param}")
    when "py"
      apppath = File.expand_path("../../", __FILE__)
      pyenvroot = @homepath + "/#{@currentuser}/.pyenv/shims/"
      pyenvroot = "" unless Dir.exist?(pyenvroot)
      python = pyenvroot + "python"
      filepath = apppath + "/bin"
      so, se, ss = Open3.capture3("#{python} #{filepath}/#{filename} #{apppath}")
    when "sh"
      filepath = File.expand_path("../../bin", __FILE__)
      param = " " + param unless param.empty?
      so, se, ss = Open3.capture3("#{filepath}/#{filename} #{cmd}#{param}")
    else
      so, se, ss = Open3.capture3("pwd")
    end
    unless ss.exitstatus.zero?
      @logger.info("'#{eventname}' failed... (code: #{ss.exitstatus})")
      @logger.info("#{se}") unless se.to_s.strip.emprt?
    end
    return so, se, ss
  end

  def running_background_processes
    @bgprocesses.each do |proname|
      t = Thread.new(proname, @logger) do |pn, lg|
        lg.info("running #{pn} on background process")
        send(pn)
      end
    end
  end
  
  # --------------------------------------------------------------------------
  def loglotate
    # log lotate for development.log/production.log
    maxlogcnt = 4
    logpath = File.expand_path("../../log", __FILE__)
    logfile = "development.log"
    logfile = "production.log" if ENV['RACK_ENV'].to_s == "production"
    maxlogcnt.times do |t|
      cnt = maxlogcnt - (t + 1)
      begin
        File.rename(logpath + "/#{logfile}.#{cnt}",
                    logpath + "/#{logfile}.#{cnt + 1}")
      rescue
      end
    end
    begin
      File.rename(logpath + "/#{logfile}", logpath + "/#{logfile}.0")
    rescue
    end
    pid = File.read(@pidfile)
    so, se, ss = Open3.capture3("kill -USR1 #{pid}")    
  end
  
  def hello
    @logger.info(" -> Hello, world!")
  end

  # --------------------------------------------------------------------------
  def mailcheck_process
    exec = "check_mail.rb"
    cmd = ""
    so, se, ss = commandexecute("mailcheck_process", exec, cmd)
    @logger.info(so) unless so.to_s.strip.empty?
    @logger.info(se) unless se.to_s.strip.empty?
  end

end

