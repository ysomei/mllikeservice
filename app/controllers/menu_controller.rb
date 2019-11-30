# -*- coding: utf-8 -*-
class MLLikeServiceWeb

  get "/" do
    erb :index
  end

  def mlpath(mladdr)
    datpath = File.expand_path("../../../data", __FILE__)
    return datpath + "/#{mladdr}"
  end
  
  # --------------------------------------------------------------------------
  get "/mladd" do
    erb :ml_add
  end
  post "/add_new_ml" do
    mlname = params[:mlname]    
    mailaddr = params[:mailaddr]
    smtpsrv = params[:smtpsrv]
    acnt = params[:account]
    passwd = params[:passwd]
    rcvtype = params[:rcvtype]
    mpath = mlpath(mailaddr)
    Dir.mkdir(mpath) unless Dir.exist?(mpath)
    if File.exist?(mpath + "/settings.yml")
      @errmsg = "ML Address already exist."
      erb :error_message
    else
      # add new ml :p
      ht = { "mlname" => mlname, "mailaddress" => mailaddr,
             "smtpserver" => smtpsrv, "rcvtype" => rcvtype,
             "account" => acnt, "password" => passwd }
      File.open(mpath + "/settings.yml", "w") do |fp|
        YAML.dump(ht, fp)
      end
      redirect root_path
    end
  end

  # --------------------------------------------------------------------------
  get "/mllist" do
    @mllist = Array.new
    datpath = File.expand_path("../../../data", __FILE__)
    Dir.glob(datpath + "/*@*").each do |list|
      ml = list.split("/").last
      mpath = mlpath(ml)
      conf = YAML.load_file(mpath + "/settings.yml")
      @mllist.push([conf["mailaddress"], conf["mlname"]])
    end
    erb :ml_list
  end

  # --------------------------------------------------------------------------
  get "/mlinfo" do
    @mladdr = params[:ml]
    mpath = mlpath(@mladdr)

    @settings = YAML.load_file(mpath + "/settings.yml")    
    @users = nil
    if File.exist?(mpath + "/users.yml")
      # user -> "mailaddr, username"
      @users = YAML.load_file(mpath + "/users.yml")
    end
    @users = Array.new if @users.nil?
    erb :ml_info
  end

  post "/update_settings" do
    mladdr = params[:mladdr]
    mlname = params[:mlname]
    smtpsrv = params[:smtpsrv]
    rcvtype = params[:rcvtype]
    acnt = params[:acnt]
    passwd = params[:passwd]

    mpath = mlpath(mladdr)
    ht = { "mlname" => mlname, "mailaddress" => mladdr,
           "smtpserver" => smtpsrv, "rcvtype" => rcvtype,
           "account" => acnt, "password" => passwd }
    File.open(mpath + "/settings.yml", "w") do |fp|
      YAML.dump(ht, fp)
    end
    
    @settings = YAML.load_file(mpath + "/settings.yml")
    erb :_mlsettings, :layout => false
  end

  # --------------------------------------------------------------------------
  post "/add_new_user" do
    @mladdr = params[:mladdr]
    umail = params[:umail]
    uname = params[:uname]

    mpath = mlpath(@mladdr)
    if File.exist?(mpath + "/users.yml")
      us = YAML.load_file(mpath + "/users.yml")
      us = Array.new if us.nil?
      us.push("#{umail},#{uname}")
    else
      us = ["#{umail},#{uname}"]
    end
    File.open(mpath + "/users.yml", "w") do |fp|
      YAML.dump(us, fp)
    end              

    @users = YAML.load_file(mpath + "/users.yml")
    erb :_mlusers, :layout => false
  end

  post "/update_userinfo" do
    @mladdr = params[:mladdr]
    newmail = params[:newmail]
    newname = params[:newname]
    pno = params[:pno].to_i

    us = nil
    mpath = mlpath(@mladdr)
    if File.exist?(mpath + "/users.yml")
      us = YAML.load_file(mpath + "/users.yml")
    end
    unless us.nil?
      us.each_with_index do |u, i|
        if i == pno
          us[i] = "#{newmail},#{newname}"
          break
        end
      end
      # update!
      File.open(mpath + "/users.yml", "w") do |fp|
        YAML.dump(us, fp)
      end
      "OK"
    else
      "users file not found"
    end
  end
  
end
