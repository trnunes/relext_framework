module Model
	class Sentence
	
		attr_accessor :id, :text, :relation, :tokens, :token_radicals
		attr_accessor :principal_entity, :secondary_entity, :offset
		attr_accessor :tokenizer, :radical_extractor, :text_cleaner
		def initialize()			
		end
		
		def tokenize
			@tokens ||= @tokenizer.tokenize(self)
			@tokens
		end
		
		def clean_text
			@text = @text_cleaner.clean(text)
		end
		
		def radicals
			clean_text
			tokenize
			@tokens.map{|token| @radical_extractor.extract_radical(token)}			
		end	
	end
	
	class Relation
		attr_accessor :principal_entity, :relation, :secondary_entity, :offset
    def initialize(principal_entity, relation, secondary_entity, offset)
      @principal_entity = principal_entity
      @relation = relation
      @secondary_entity = secondary_entity
      @offset = offset
    end
	end
	
	class Entity
		attr_accessor :id, :label, :types
		def initialize(id)
			@id = id
      @types = []
		end
	end
end