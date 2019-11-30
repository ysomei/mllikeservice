# -*- coding: utf-8 -*-
require "yaml"
require "logger"
require_relative "../config/initializers/mail"

class CheckMail

  def initialize
    @datpath = File.expand_path("../../data", __FILE__)

    logpath = File.expand_path("../../log", __FILE__)
    @logger = Logger.new(logpath + "/checkmail.log", 2, 1024 * 1024)
    @logger.level = Logger::DEBUG
    @logger.formatter = proc{|s, d, p, m| "#{d.to_s[0, 19]} #{p}[#{$$}] #{m}\n"}
    @logger.info("Start ML Like Service.")
  end

  # ML一覧取得
  def get_mllist
    list = Array.new
    Dir.glob(@datpath + "/*@*").each do |file|
      list.push(file.split("/").last)
    end
    return list
  end

  # ML設定取得
  def get_settings(mladdr)
    settings = nil
    mpath = @datpath + "/#{mladdr}"
    if File.exist?(mpath + "/settings.yml")
      settings = YAML.load_file(mpath + "/settings.yml")
    else
      # settings file not found...
    end
    return settings
  end

  # recvfrom: recv[:from]
  def parse_fromaddr(recvfrom)
    from = recvfrom.gsub(/\r|\n/, "").gsub("From: ", "")
    naddr = from.split(" ").last; naddr.gsub!(/\<|\>/, "")
    return naddr
  end
  # recvrcpt: recv[:rcpt]
  def parse_rcptaddr(recvrcpt)
    rcpt = recvrcpt.gsub(/\r|\n/, "").gsub("To: ", "")
    naddr = rcpt.split(" ").last; naddr.gsub!(/\<|\>/, "")
    return naddr
  end
  # recvaddr: recv[:recvd]
  def parse_recvaddr(recvaddr)
    recvby = ""
    recvaddr.gsub(/\r|\t/, "").split("\n").each do |recv|
      recv.gsub!("Received: ", "")
      rs = recv.scan(/by .+ with/).flatten.first
      recvby = rs unless rs.nil?
    end
    return recvby.split(" ")[1]
  end

  # 差出人ドメインチェック
  def mail_from_check(recvmail)
    ret = false
    from = parse_fromaddr(recvmail[:from])
    recvaddr = parse_recvaddr(recvmail[:recvd])
    fromdomain = from.scan(/@.+/).flatten.first.gsub("@", "")
    fromdomain.chop! if fromdomain[-1] == ">"

    # domain change :p
    dch = { "gmail.com" => "google.com" }
    fromdomain = dch[fromdomain] if dch.keys.include?(fromdomain)
    regstr = Regexp.new(fromdomain)
    ret = true if recvaddr =~ regstr
    return ret    
  end

  # メールが ML として送信されたかどうかチェック
  def mail_ml_check(recvmail)
    ret = false
    subj = recvmail[:subject]
    rcpt = parse_rcptaddr(recvmail[:rcpt])
    regstr = Regexp.new("^\[" + rcpt.split("@").first + "\:\\d{4}\]")
    ret = true if subj =~ regstr
    return ret
  end

  # MLメンバーかどうかチェック
  def ml_member_check(mladdr, mailaddr)
    ret = false
    mlpath = @datpath + "/#{mladdr}"
    users = YAML.load_file(mlpath + "/users.yml")
    users = Array.new if users.nil?
    users.each do |user|
      addr, name = user.split(",")
      regstr = Regexp.new(addr)
      if mailaddr =~ regstr
        ret = true
        break
      end
    end
    return ret
  end

  # メールを読込んで、メンバーから送信されたものはML送信
  def mailread_and_send(mladdr)
    settings = get_settings(mladdr)
    mladdr = settings["mailaddress"]
    mail = MLMail.new(settings)

    # POP3 の場合既読チェックするのでパスを設定
    if settings["rcvtype"].to_s.strip.upcase == "POP3"
      rpath = @datpath + "/#{mladdr}/pop3reaed.dat"
      mail.pop3readedpath = rpath
    end
    
    recvs = mail.read # mail read!
    recvs.each_with_index do |recv, i|
      next if mail_ml_check(recv) # mail ga ML nara skip!
      next unless mail_from_check(recv) # fromaddr ga received domain denaika 
      from = parse_fromaddr(recv[:from])
      if ml_member_check(mladdr, from)
        send_mlmail(mladdr, mail, recv) # including mlhash check :p
      else
        # @logger.info(" from unknown Member #{from}")
      end
    end
  end

  def send_mlmail(mladdr, mail, recvdata)
    users = YAML.load_file(@datpath + "/#{mladdr}/users.yml")
    userinfos = users.collect{|c| c.split(",")}
    hkey = calculate_mlhash(recvdata)
    isNew, cnt = check_mlhash(mladdr, hkey)
    if isNew
      # it's new! send!
      from = parse_fromaddr(recvdata[:from])
      @logger.info(" find Mail from #{from}")
      
      mlhead = "[" + parse_rcptaddr(recvdata[:rcpt]).split("@").first
      mlhead += ":" + ("%04d" % cnt) + "]"
      subj = mlhead + " " + recvdata[:subject].to_s.strip
      body = recvdata[:body]
      body = "posted by #{recvdata[:from]}\r\n\r\n" + body
      
      userinfos.each_with_index do |u, i|
        rcpt_to = "#{u[1]} <#{u[0]}>"
        mail.send(:rcpt_to => rcpt_to,
                  :subject => subj, :body => body)
        sleep(1) if i < (userinfos.length - 1)
      end

      # add mailhashlist.csv :p
      mlpath = @datpath + "/#{mladdr}"
      File.open(mlpath + "/mailhashlist.csv", "a") do |fp|      
        fp.puts "#{cnt},#{hkey}"
      end      
      @logger.info(" send to #{mlhead} done.")   
    else
      # already sending...
    end
  end

  def calculate_mlhash(recvdata)
    from = parse_fromaddr(recvdata[:from])
    date = recvdata[:date]
    subj = recvdata[:subject]
    body = recvdata[:body]
    return Digest::SHA1.hexdigest(from + date + subj + body)
  end
  
  def check_mlhash(mladdr, mlhash)
    mlpath = @datpath + "/#{mladdr}"
    unless File.exist?(mlpath + "/mailhashlist.csv")
      File.open(mlpath + "/mailhashlist.csv", "w") do |fp|
        fp.puts "id,hkey"
      end
    end
    i = 0; isAdd = true
    File.open(mlpath + "/mailhashlist.csv", "r") do |fp|
      fp.each_line do |line|
        unless i.zero?
          items = line.split(",")
          hkey = items[1].to_s.strip
          if mlhash == hkey
            isAdd = false
            break
          end
        end
        i += 1
      end
    end
    return isAdd, i
  end

  # --------------------------------------------------------------------------
  def mlprocess
    get_mllist.each do |mladdr|
      @logger.info("-- #{mladdr} --")
      mailread_and_send(mladdr)
    end
  end
  
end

# ----------------------------------------------------------------------------
if __FILE__ == $0
  # run
  cm = CheckMail.new
  cm.mlprocess
end
