# -*- coding: utf-8 -*-
require "net/pop"
require "net/imap"
require "base64"
require "mail"

class RMail
  include Mail
end

class MLMail
  attr_accessor :host, :username, :password, :reader, :mladdr,
                :mladdr, :mlname, :smtpport, :starttls,
                :pop3readedpath
  def initialize(settings)
    @host = settings["smtpserver"].to_s
    @username = settings["account"].to_s
    @password = settings["password"].to_s
    @reader = settings["rcvtype"].to_s
    @mladdr = settings["mailaddress"].to_s
    @mlname = settings["mlname"].to_s.strip

    @smtpport = settings["smtpport"].to_i
    @smtpport = 587 if @smtpport.zero?
    @starttls = true
    
    @cacpath = File.expand_path("../../var", __FILE__)
    if File.exist?("/mnt/ramdisk/.ramdisk")
      @cacpath = "/mnt/ramdisk/cache"
      Dir.mkdir(@cacpath) unless Dir.exist?(@cacpath)
    end

    @pop3readedpath = nil # pop3で既読のUIDLを保存しておくファイル名（fullpath)
  end
  
  def read
    return nil if @host.to_s.strip.empty?
    return pop(:apop => false) if @reader == "POP3"
    return imap
  end
  
  # ------------------------------------------------------------------------
  # MIME-encoding: =?utf-8?b? + base64-encoded-string + ?=
  def mime_decode(str, charset = "UTF-8")
    decstr = ""
    items = str.split(/\s/).collect{|c| c.strip}
    items.each_with_index do |item, i|
      if item.empty?
        decstr += " "
        next
      end
      decstr += " " unless decstr.empty?
      mis = item.scan(/^=\?(UTF-8|utf-8)\?(B|b)\?(.+)\?=$/).flatten
      if mis.empty?
        decstr += item
      else
        decstr += Base64.decode64(mis[-1])
      end
    end
    return msg_decode(decstr, charset)
  end
  
  def msg_decode(str, charset = nil)
    return str if charset.nil?

    charset.gsub!("\"", "")
    skey = Digest::MD5.hexdigest("#{charset}_#{str.length}_#{Time.now}")
    File.open(@cacpath + "/#{skey}", "w") do |fp|
      fp.write(str)
    end
    str = File.read(@cacpath + "/#{skey}", :encoding => charset.downcase)
    File.unlink(@cacpath + "/#{skey}")
    return str.to_s.strip.encode("utf-8").gsub("\r", "")
  end
  
  def body_decode(str, benc = "")
    charset = nil; enctype = ""; encstr = ""; boundary = ""
    str.split("\n").each_with_index do |line, i|
      boundary = "#{line}" if i.zero?
      if line =~ /Content-Type/
        charset = line.scan(/charset=(.+)/).flatten.first
        next
      end
      if line =~ /Transfer-Encoding/
        enctype = line.split(": ").last.strip
        next
      end
      next if line == boundary || line == ("#{boundary}--")
      encstr += line
    end

    if enctype.empty?
      enctype = benc
      encstr = str
    end
    if enctype == "base64"
      encstr.gsub!("\n", "")
      decstr = Base64.decode64(encstr)
    else
      decstr = encstr
    end
    return msg_decode(decstr, charset)
  end
  
  # ------------------------------------------------------------------------
  # options -> :apop => true/false  default is false
  def pop(**options)
    messages = Array.new

    isapop = false
    isapop = options[:apop] unless options.keys.include?(:apop)
    return nil if @host.nil? || @username.nil? || @password.nil?

    fp = nil
    unless @pop3readedpath.nil?
      unless File.exist?(@pop3readedpath)
        File.open(@pop3readedpath, "w"){|fp| }
      end
      fp = File.open(@pop3readedpath, "r+")
    end
    
    recv = Net::POP3.APOP(isapop).new(@host, 110)
    recv.start(@username, @password){|r|
      mailcnt = r.mails.count
      r.mails.each_with_index do |m, i|
        # -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
        uidl = m.uidl
        isReaded = false
        unless fp.nil?
          fp.each_line do |line|
            if line.to_s.strip == uidl
              isReaded = true
              break
            end
          end
        end
        next if isReaded
        # -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
        
        srcstr = m.pop
        hfrom = ""; hto = ""
        subject = ""; charset = ""; body = ""; datestr = ""; benc = ""
        recvd = ""
        selitem = ""; isBody = false
        srcstr.split("\n").each do |sstr|
          sstr.gsub!("\r", "")
          # header parse :p
          items = sstr.split(": ")
          selitem = items[0] if items.length > 1
          if isBody
            body += sstr + "\n"
          else
            case selitem
            when "From"
              hfrom = items[-1]
            when "To"
              hto = items[-1]
            when "Date"
              datestr = items[-1]
              selitem = ""
            when "Subject"
              subject += sstr.gsub("Subject: ", "")
            when "Content-Type"
              charset = items[1].scan(/charset=(.+)\;/).flatten.first
              selitem = ""
            when "Content-Transfer-Encoding"
              benc = items[-1]
              selitem = ""
            when "Content-Language"
              selitem = ""
            when "Received"
              recvd += sstr + "\r\n"
            end
          end
          isBody = true if sstr.empty?            
        end
        title = mime_decode(subject)
        dat = body_decode(body, benc)
        
        ht = Hash.new
        ht[:msgid] = (i + 1)
        ht[:recvd] = recvd
        ht[:from] = hfrom
        ht[:rcpt] = hto
        ht[:subject] = title
        ht[:date] = datestr
        ht[:body] = dat.to_s.force_encoding("utf-8")

        messages.push(ht)

        # -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-        
        unless fp.nil?
          fp.puts uidl # 既読済みに設定 (UIDL で識別)
        end
        # -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
        
        #m.delete
      end
    }
    fp.close unless fp.nil?
    return messages
  end
  
  # ------------------------------------------------------------------------
  def imap
    messages = Array.new
    
    search_attr = ["UNSEEN"] #["ALL"] # UNSEEN
    recvd_attr = "BODY[HEADER.FIELDS (RECEIVED)]"
    from_attr = "BODY[HEADER.FIELDS (FROM)]"
    rcpt_attr = "BODY[HEADER.FIELDS (TO)]"
    subject_attr = "BODY[HEADER.FIELDS (SUBJECT)]"
    date_attr = "BODY[HEADER.FIELDS (DATE)]"
    body_attr = "BODY[1]" # -> rfc2060_6.4.5  1 = TEXT/PLAIN
    bodytype_attr = "BODY"
    
    recv = Net::IMAP.new(@host)
    recv.authenticate("LOGIN", @username, @password)
    #recv.examine("INBOX")
    recv.select("INBOX") # <- 一度読んだものは既読になって次回は読み込まない
    recv.search(search_attr).each do |msgid|
      msg = recv.fetch(msgid, [recvd_attr, from_attr, rcpt_attr,
                               subject_attr, date_attr,
                               body_attr, bodytype_attr]).first
      recvd = msg.attr[recvd_attr]
      from = msg.attr[from_attr]
      rcpt = msg.attr[rcpt_attr]
      subject = msg.attr[subject_attr]
      title = mime_decode(subject.gsub("Subject: ", ""))
      datestr = msg.attr[date_attr].to_s.strip.gsub("Date: ", "")
      
      body = msg.attr[body_attr]
      bodytype = msg.attr[bodytype_attr]
      benc = ""
      charset = "UTF-8"
      case bodytype.class.to_s
      when "Net::IMAP::BodyTypeMultipart"
        benc = bodytype.parts[0].encoding
        charset = bodytype.parts[0].param["CHARSET"]
      else
        # BodyTypeText, BodyTypeMessage, BodyTypeBasic
        benc = bodytype.encoding
        charset = bodytype.param["CHARSET"]
      end
      dat = body
      dat = Base64.decode64(body) if benc == "BASE64"
      dat = msg_decode(dat, charset)
      
      ht = Hash.new
      ht[:msgid] = msgid
      ht[:recvd] = recvd
      ht[:from] = from
      ht[:rcpt] = rcpt
      ht[:date] = datestr
      ht[:subject] = title
      ht[:body] = dat
      messages.push(ht)

      #recv.store(msgid, "+FLAGS", [:Seen, :Deleted])
    end
    recv.close
    recv.logout
    
    return messages
  end
  
  # ------------------------------------------------------------------------
  # options: :body => mail body
  #          :subject => mail title
  #          :rcpt_to => reciever mail-address
  #          [:mail_from => sender mail-address] default -> settings.yml
  def send(**options)
    cnt = 0
    chkeys = [:subject, :body, :rcpt_to]
    options.keys.each do |k|
      cnt += 1 if chkeys.include?(k)
    end
    return false if cnt != chkeys.length
    
    rcpt = Array.new # send to user-mailaddress
    unless options[:rcpt_to].nil?
      rcpt.push(options[:rcpt_to])
    end
    if options[:mail_from].to_s.strip.empty?
      unless @mlname.empty?
        options[:mail_from] = "#{@mlname} <#{@mladdr}>"
      else
        options[:mail_from] = @mladdr
      end
    end

    smtpserver = @host # :p
    if smtpserver.to_s.strip.empty?
      emsg = "unknown mail server (host is empty)."
      raise MLMailError.new(emsg)
    end
    smtpport = @smtpport
    
    mail = RMail::Message.new
    mail.return_path = options[:return_path]
    mail.from = options[:mail_from]
    mail.to = rcpt
    mail.subject = options[:subject]
    mail.body = options[:body]
    smtpinfos = { :address => smtpserver,
                  :port => smtpport,
                  :enable_starttls_auto => @starttls }
    if @starttls
      smtpinfos[:authentication] = "plain"
      smtpinfos[:user_name] = @username
      smtpinfos[:password] = @password
    end
    mail.delivery_method(:smtp, smtpinfos)
    mail.deliver
    return true
  end
  
end

class MLMailError < StandardError
end
