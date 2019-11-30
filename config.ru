require_relative "./config/boot"
#run MLLikeServiceWeb
run Rack::URLMap.new(
  { "/" => MLLikeServiceWeb }
)

