# -*- coding: utf-8 -*-
class MLLikeServiceWeb

  # --------------------------------------------------------------------------
  get "/hello" do
    name = params[:name].to_s.strip
    name = "world" if name.empty?
    "Hello, #{name}!"
  end
  
  # --------------------------------------------------------------------------
  # error
  error 401 do
    "Authentication Error"
  end
end

