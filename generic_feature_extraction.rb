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
			tokens = tokenizer.tokenize(sentence).map{|token| normalizer.normalize(token).gsub(/\W/, "")}
            tokens.delete("")
            tokens
		end
		
	end  
  
  class ShortestPathExtractor
    attr_accessor :primary_entity_recognizer, :secondary_entity_recognizer, :dependency_list_finder
		    
    def extract(sentence)
      result = ""
      entity1_match = @primary_entity_recognizer.call(sentence)      
      entity2_match = @secondary_entity_recognizer.call(sentence)
      
      if(!entity1_match.nil?)
          sentence.text = sentence.text.sub(entity1_match[0], "Entity1")
      end
      
      if(!entity2_match.nil?)
          sentence.text = sentence.text.sub(entity2_match[0], "Entity2")
      end
      
      dependency_list = @dependency_list_finder.call(sentence)
      
      entity1 = nil
      entity2 = nil

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
        result =[]
        
        previous_node = path.delete(path[0])
        path.each{|node|
            result << previous_node.label.to_s + direction_hash[node] + node.label.to_s
            previous_node = node
        }
        
      else

      end
      result
    end
  end
end