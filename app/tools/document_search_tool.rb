class DocumentSearchTool
  def self.name
    "document_search"
  end

  def self.description
    "Busca documentos jurídicos relevantes na base de conhecimento do Dr. Rafael"
  end

  def self.parameters_schema
    {
      "type" => "OBJECT",
      "properties" => {
        "query" => {
          "type" => "STRING",
          "description" => "Consulta ou pergunta sobre leis, processos ou documentos jurídicos"
        }
      },
      "required" => ["query"]
    }
  end

  def call(query:)
    results = Document.semantic_search(query, limit: 3)
    
    if results.empty?
      return "Nenhum documento relevante encontrado para a consulta: #{query}"
    end

    formatted_results = results.map do |doc|
      "Fonte: #{doc.filename} | Conteúdo: #{doc.content[0..500]}..."
    end

    formatted_results.join("\n\n")
  end
end
