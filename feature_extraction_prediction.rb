module FeatureExtractionPrediction
  LOG = './log/feature_extraction_prediction.log'
  File.open(LOG, 'w'){|f| f.write("")}
  
  def self.log(msg)
    File.open(LOG, 'a'){|f| f.write(msg << "\n")}
  end
  
  def self.add_extractor(feature_extractor)
    @@extractors ||= []
    @@extractors << feature_extractor 
  end
  
  def self.extract(sentence)
    feature_matrix = []
    # puts "SENTENCE AT FEATURE EXTRACTION: #{sentence.text}"
    @@extractors.each{|extractor|
      feature_matrix += extractor.extract(sentence)
    }
    
    feature_matrix << "?"
  end
  
  def self.get_attributes
    attributes = []
    @@extractors.each{|extractor| attributes += extractor.get_attributes}
    attributes << 'property'
    puts 'GETTING ATTRIBUTES'
    attributes
  end
  
  class FeatureExtractor
    attr_accessor :radical_extractor, :corref_analyser, :parser
    
    def initialize(repository, uri_pattern=nil)
      @repository = repository      
      @uri_pattern = uri_pattern
    end
    
    def get_attributes
    end
  end
  
  class ParseTreeExtractor  < FeatureExtractor
    attr_accessor :corref_analyser, :parser
    
    def initialize(repository, uri_pattern=nil)
      @repository = repository
      # @parser = NLP::StanfordDependencyParser.new('lib/stanford-parser-2012-03-09/englishPCFG.ser.gz')      
    end
    
    def get_attributes
      @attributes ||= @repository.find_all_shortest_paths.flatten.map{|attr|        
        attr = "->" << attr if !attr.include?("-")          
        word = attr.gsub("->", "").gsub("<-", "")        
        attr.gsub(word, word.stem.removeaccents).downcase
      }.uniq
      puts "SHORTEST PATHS: " + @attributes.size.to_s
      @attributes
    end
    
    def select_subject(tdl)
      tdl.select{|td| td.reln.to_s.include?("subj")}
    end
    
    def find_entity_indexes(tdl)
      sentence_subjects = select_subject(tdl)      
    end    
    
    def calculate_shortest_path(sentence)
      puts "CALCULATING SHORTEST PATH"
      
      principal_entity_node = nil
      secondary_entity_node = nil
      path = nil                  
      text = sentence.text.dup      
      
      # Computing the dependency list, with govs and deps
      tdl = @parser.compute_dependency_list(sentence)
      FeatureExtractionPrediction.log("DEPENDENCY LIST: #{tdl.map{|dp| dp.relation + ":" + dp.gov.label + ":" + dp.dep.label}.inspect}")
      
      
      tdl.each{|td| 
        principal_entity_node = td.dep if td.dep.label.include?("EP")
        principal_entity_node = td.gov if td.gov.label.include?("EP")
        secondary_entity_node = td.dep if td.dep.label.include?("SE2")
        secondary_entity_node = td.gov if td.gov.label.include?("SE2")        
      }
      FeatureExtractionPrediction.log("PRINCIPAL NODE: #{principal_entity_node}")
      FeatureExtractionPrediction.log("SECONDARY NODE: #{secondary_entity_node}")     
        
      # the shortest path strategy: Dijkstra
      dijkstra = Graph::Dijkstra.new()
      # computing the undirected shortest path
      path, direction_hash = NLP.compute_shortest_path(tdl, principal_entity_node, secondary_entity_node, dijkstra)        
      FeatureExtractionPrediction.log(" SHORTEST PATH: #{path.map{|node|direction_hash[node]+node.to_s}.join}")
      FeatureExtractionPrediction.log("")   
      path.nil??nil:path.map{|node|direction_hash[node]+node.label.to_s}
    end
    
    def extract(sentence, include_response = false)
      attributes = get_attributes
      puts "ATTR SIZE: " + attributes.size.to_s
      feature_vector = Array.new(attributes.size, 0)
      feature_vector[attributes.size - 1] = sentence.relation if include_response
      puts "FINDING PATH"            
      path ||= calculate_shortest_path(sentence)
      puts "PATH: #{path.inspect}"
      puts "TRYING TO SET FEATURE"
      path.each{|word_and_direction|        
        word_and_direction = "->" << word_and_direction if !word_and_direction.include?("-")
        word_and_direction.downcase!
        word = word_and_direction.gsub("->", "").gsub("<-", "")        
        word_and_direction.gsub!(word, word.stem.removeaccents)
        index = attributes.index(word_and_direction)
        puts "#{index}: "+word_and_direction
        feature_vector[index] = 1 if index        
      }
      puts "VECTOR SIZE: " + feature_vector.size.to_s
      puts "features captured: " + feature_vector.select{|f|f == 1}.size.to_s
      puts "END TRYING TO SET FEATURE"         
      feature_vector      
    end
  end
  
  class LexicalExtractor < FeatureExtractor
    
    def get_attributes
      return @attributes if @attributes      
      @attributes = @repository.find_words
      if @radical_extractor
#        puts "RADICAL EXTRACTOR"
        @attributes.map!{|attr|@radical_extractor.extract_radical(attr.removeaccents)}.uniq!
      end
      @attributes
    end
    
    def extract(sentence, include_response = false)
      # puts "extracting feature for : #{sentence.relation}"
      attributes = get_attributes
#      puts "LEXICAL ATTR SIZE: #{attributes.size}"
      feature_vector = Array.new(attributes.size, 0)
#      puts "FEATURE VECTOR INITIALIZED"
      feature_vector[attributes.size - 1] = sentence.relation if include_response     
      # puts "STARTING FEATURE VECTOR SEARCH"
      sentence.radicals.each{|radical|
        index = attributes.index(radical.removeaccents)
        if index
#           puts "#{index}: #{radical}"
          feature_vector[index] = 1
        end
      }
#       puts "ENDING FEATURE VECTOR SEARCH"
      # puts "INSPECT #{feature_vector.inspect}"
      feature_vector
    end    
  end
  
  class EntityTypesExtractor < FeatureExtractor
  
    
    def get_attributes
      return @attributes if @attributes
      dbpedia_ont_classes = @repository.find_all_classes("http://dbpedia.org/ontology/")
      puts "I'M IN ENTITY TYPES EXTRACTOR"
      puts dbpedia_ont_classes
      @attributes = dbpedia_ont_classes.dup      
      @attributes += dbpedia_ont_classes.map{|attr| attr.dup << "SE"}      
      @attributes
    end
    
    def extract(sentence, include_response = false)
      attributes = get_attributes
      puts attributes.inspect
      feature_vector = Array.new(attributes.size, 0)
      feature_vector[attributes.size - 1] = sentence.relation if include_response
      puts ""
      sentence.principal_entity.types.each{|type|
        index = attributes.index(type)
        if index
          puts type
          feature_vector[index] = 1 if type.include?("http://dbpedia.org/ontology/")
        else
          puts "NOT FOUND: #{type}"
        end
        
      }
      sentence.secondary_entity.types.each{|type|
        # puts type        
        rindex = attributes.rindex(type.dup<<"SE")
        if(rindex)
          puts "Secondary Entity Type: " + type
          feature_vector[rindex] = 1 if type.include?("http://dbpedia.org/ontology/")
        else
          puts "Secondary Entity Type Not Found: " + type
        end
      }
      feature_vector
    end
    
  end
end