# Configurar Zeitwerk para reconhecer "AI" como acrônimo
# Isso permite que open_ai_audio_service.rb seja carregado como OpenAIAudioService
Rails.autoloaders.each do |autoloader|
  autoloader.inflector.inflect(
    "ai" => "AI"
  )
end

