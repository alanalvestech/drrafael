class AudioResponseFormatter
  # Estima que 1 minuto de áudio = ~150 palavras (fala normal em português)
  # ElevenLabs gera áudio a ~150 palavras/minuto
  WORDS_PER_MINUTE = 150
  MAX_AUDIOS = 3
  MAX_WORDS_PER_AUDIO = WORDS_PER_MINUTE # 1 minuto por áudio

  # Resumir texto se necessário e dividir em chunks de ~1 minuto
  # Retorna array de textos (máximo 3 chunks)
  def self.format_for_audio(text)
    return [] if text.blank?

    # Remover quebras de linha excessivas e espaços múltiplos
    cleaned_text = text.gsub(/\n{3,}/, "\n\n").gsub(/[ \t]+/, " ").strip
    
    # Contar palavras
    words = cleaned_text.split(/\s+/)
    total_words = words.length

    Rails.logger.info "📝 Texto original: #{total_words} palavras"
    STDOUT.puts "📝 Texto original: #{total_words} palavras"

    # Se o texto for muito longo, resumir primeiro
    max_total_words = MAX_AUDIOS * MAX_WORDS_PER_AUDIO
    if total_words > max_total_words
      Rails.logger.info "📝 Texto muito longo (#{total_words} palavras), resumindo para #{max_total_words} palavras"
      STDOUT.puts "📝 Texto muito longo, resumindo..."
      cleaned_text = summarize_text(cleaned_text, max_words: max_total_words)
      words = cleaned_text.split(/\s+/)
      total_words = words.length
    end

    # Dividir em chunks de ~1 minuto (150 palavras)
    chunks = []
    current_chunk = []
    current_words = 0

    words.each do |word|
      # Se o chunk atual já tem ~1 minuto, finalizar e começar novo
      if current_words >= MAX_WORDS_PER_AUDIO && chunks.length < MAX_AUDIOS - 1
        chunks << current_chunk.join(" ")
        current_chunk = []
        current_words = 0
      end

      current_chunk << word
      current_words += 1
    end

    # Adicionar último chunk se houver
    if current_chunk.any?
      chunks << current_chunk.join(" ")
    end

    # Limitar a 3 áudios
    chunks = chunks.first(MAX_AUDIOS)

    Rails.logger.info "📦 Texto dividido em #{chunks.length} chunk(s) de áudio"
    STDOUT.puts "📦 Texto dividido em #{chunks.length} chunk(s) de áudio"
    
    chunks.each_with_index do |chunk, index|
      word_count = chunk.split(/\s+/).length
      Rails.logger.info "  Chunk #{index + 1}: #{word_count} palavras (~#{word_count.to_f / WORDS_PER_MINUTE * 60} segundos)"
      STDOUT.puts "  Chunk #{index + 1}: #{word_count} palavras"
    end

    chunks
  end

  private

  # Resumir texto mantendo informações importantes
  # Usa uma abordagem simples: pega primeiras e últimas frases + frases do meio
  def self.summarize_text(text, max_words:)
    sentences = text.split(/[.!?]+/).map(&:strip).reject(&:blank?)
    return text if sentences.length <= 3

    target_sentences = (max_words / 15.0).ceil # ~15 palavras por frase
    return text if sentences.length <= target_sentences

    # Pegar primeiras frases (contexto inicial)
    first_count = [target_sentences / 3, 2].max
    # Pegar últimas frases (conclusão)
    last_count = [target_sentences / 3, 2].max
    # Pegar frases do meio (desenvolvimento)
    middle_count = target_sentences - first_count - last_count

    selected = []
    selected += sentences.first(first_count)
    
    if middle_count > 0 && sentences.length > first_count + last_count
      middle_start = first_count
      middle_end = sentences.length - last_count
      step = [(middle_end - middle_start) / middle_count, 1].max
      (middle_start...middle_end).step(step).each do |i|
        selected << sentences[i] if sentences[i]
      end
    end
    
    selected += sentences.last(last_count)

    summary = selected.join(". ") + "."
    
    # Garantir que não ultrapasse o limite de palavras
    summary_words = summary.split(/\s+/)
    if summary_words.length > max_words
      summary = summary_words.first(max_words).join(" ") + "..."
    end

    summary
  end
end

