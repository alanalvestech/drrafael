namespace :data do
  desc "Ingerir PDFs de storage/pdfs e gerar embeddings"
  task ingest: :environment do
    pdf_dir = Rails.root.join("storage", "pdfs")
    
    unless Dir.exist?(pdf_dir)
      puts "Criando diretório #{pdf_dir}"
      FileUtils.mkdir_p(pdf_dir)
    end

    pdf_files = Dir.glob(pdf_dir.join("*.pdf"))
    
    if pdf_files.empty?
      puts "Nenhum arquivo PDF encontrado em #{pdf_dir}"
      exit
    end

    puts "Encontrados #{pdf_files.length} arquivo(s) PDF"
    
    api_key = ENV.fetch("GEMINI_API_KEY")
    llm = Langchain::LLM::GoogleGemini.new(api_key: api_key)
    chunker = Langchain::Chunker::RecursiveText.new(
      chunk_size: 1000,
      chunk_overlap: 200
    )

    pdf_files.each_with_index do |pdf_path, index|
      filename = File.basename(pdf_path)
      puts "\n[#{index + 1}/#{pdf_files.length}] Processando: #{filename}"
      
      begin
        # Extrair texto do PDF
        text = ""
        PDF::Reader.open(pdf_path) do |reader|
          reader.pages.each do |page|
            text += page.text + "\n"
          end
        end

        if text.strip.empty?
          puts "  ⚠️  Arquivo vazio, pulando..."
          next
        end

        # Chunking
        chunks = chunker.chunks(text)
        puts "  📄 Texto extraído: #{text.length} caracteres"
        puts "  ✂️  Dividido em #{chunks.length} chunk(s)"

        # Processar cada chunk
        chunks.each_with_index do |chunk, chunk_index|
          print "  🔄 Processando chunk #{chunk_index + 1}/#{chunks.length}... "
          
          begin
            # Gerar embedding
            embedding_response = llm.embed(
              text: chunk,
              model: "text-embedding-004"
            )
            
            embedding = embedding_response.dig("embedding") || embedding_response
            
            unless embedding.is_a?(Array) && embedding.length == 768
              puts "❌ Erro: Embedding inválido (esperado array de 768 elementos)"
              next
            end

            # Salvar no banco
            Document.create!(
              content: chunk,
              filename: filename,
              embedding: embedding,
              metadata: {
                chunk_index: chunk_index,
                total_chunks: chunks.length,
                file_path: pdf_path.to_s
              }
            )
            
            print "✅\n"
          rescue => e
            puts "❌ Erro: #{e.message}"
            Rails.logger.error "Erro ao processar chunk: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
          end
        end

        puts "  ✅ #{filename} processado com sucesso"
      rescue => e
        puts "  ❌ Erro ao processar #{filename}: #{e.message}"
        Rails.logger.error "Erro ao processar PDF: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      end
    end

    total_documents = Document.count
    puts "\n🎉 Ingestão concluída! Total de documentos no banco: #{total_documents}"
  end
end

