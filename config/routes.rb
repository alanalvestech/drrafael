Rails.application.routes.draw do
  root "application#health"
  
  get "/health", to: "application#health"
  post "/webhook/whatsapp", to: "webhook#whatsapp"
end

