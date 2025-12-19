class Document < ApplicationRecord
  has_neighbors :embedding

  def self.semantic_search(query, limit: 5)
    return [] if query.blank?

    # Gerar embedding usando serviço direto (contorna bug do langchainrb)
    query_embedding = GeminiEmbeddingService.embed(query, model: "text-embedding-004")
    
    return [] unless query_embedding.is_a?(Array)

    # Buscar vizinhos mais próximos
    nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .limit(limit)
  end
end

