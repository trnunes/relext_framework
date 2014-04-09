require 'stemmer'
require 'information_extraction.rb'
require 'graph.rb'
require 'nlp.rb'
require 'extended_string'
module GenericFeatureExtraction
  
# Acrescentar pre e pos processamento
  LOG = './log/feature_extraction.log'
  File.open(LOG, 'w'){|f| f.write("")}
  def self.feature_repo; @@feature_repo end
  def self.feature_repo= v; @@feature_repo = v end
  
  def self.log(msg)
    File.open(LOG, 'a'){|f| f.write(msg << "\n")}
  end
  
	def self.add_extractor(feature_extractor)
		@@extractors ||= []
		@@extractors << feature_extractor	
	end
	
	def self.extract(sentence)
		features = []
		@@extractors.each{|extractor|
			features = extractor.extract(sentence)
			if(!features.empty?)
			 @@feature_repo.save_features(sentence, features, extractor.class)
		  end		
		}		
	end

	class EntityTypesExtractor
		attr_accessor :types_finder
		
		def extract(sentence)
			types = sentence.principal_entity.types + sentence.secondary_entity.types.map{|type| type.dup<<"_SE"}
			types
		end
		
	end
	
	class LexicalExtractor
		attr_accessor :normalizer, :tokenizer
	
		def extract(sentence)
			tokenizer.tokenize(sentence).map{|token| normalizer.normalize(token)}
		end
		
	end  
  
  class ShortestPathExtractor
    attr_accessor :primary_entity_recognizer, :secondary_entity_recognizer, :dependency_list_finder
		    
    def extract(sentence)
      result = ""
      entity1_match = @primary_entity_recognizer.call(sentence)      
      entity2_match = @secondary_entity_recognizer.call(sentence)
      
      sentence.text = sentence.text.dup.gsub(entity1_match[0], "Entity1").gsub(entity2_match[0], "Entity2")
      dependency_list = @dependency_list_finder.call(sentence)
      entity1 = nil
      entity2 = nil
      puts "DEP LIST #{dependency_list}"
      dependency_list.each{|dp|
        entity1 =  dp.dep if dp.dep.label.include?("Entity1")
        entity1 =  dp.gov if dp.gov.label.include?("Entity1")
        entity2 =  dp.dep if dp.dep.label.include?("Entity2")
        entity2 =  dp.gov if dp.gov.label.include?("Entity2")
      }
      if entity1 != nil && entity2 != nil
        dijkstra = Graph::Dijkstra.new()
        # computing the undirected shortest path
        path, direction_hash = NLP.compute_shortest_path(dependency_list, entity1, entity2, dijkstra)
        result = path.map{|node|direction_hash[node]+node.label.to_s}.join
        FeatureExtraction.log(" SHORTEST PATH: #{result}")        
      end
      result
    end
  end
end