class Document < ApplicationRecord
  has_neighbors :embedding

  def self.semantic_search(query, limit: 5)
    return [] if query.blank?

    api_key = ENV.fetch("GEMINI_API_KEY")
    llm = Langchain::LLM::GoogleGemini.new(api_key: api_key)

    # Gerar embedding da query usando text-embedding-004
    embedding_response = llm.embed(
      text: query,
      model: "text-embedding-004"
    )

    query_embedding = embedding_response.dig("embedding") || embedding_response
    return [] unless query_embedding.is_a?(Array)

    # Buscar vizinhos mais próximos
    nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .limit(limit)
  end
end

