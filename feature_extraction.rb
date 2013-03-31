require 'stemmer'
require 'information_extraction.rb'
require 'graph.rb'
require 'nlp.rb'
require 'extended_string'
module FeatureExtraction

# Acrescentar pre e pos processamento
  LOG = './log/feature_extraction.log'
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
		
		feature_matrix << "'#{sentence.relation}'"
	end
	
	def self.get_attributes
		attributes = []
		@@extractors.each{|extractor| attributes += extractor.get_attributes}
		attributes << 'property'
		
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
  
	class EntityTypesExtractor < FeatureExtractor
	
		
		def get_attributes
			return @attributes if @attributes
      dbpedia_ont_classes = @repository.find_all_classes("http://dbpedia.org/ontology/")
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
        else
          puts "NOT FOUND: #{type}"
        end
				feature_vector[index] = 1 if type.include?("http://dbpedia.org/ontology/")
			}
			sentence.secondary_entity.types.each{|type|
				# puts type
				feature_vector[attributes.rindex(type.dup<<"SE")] = 1 if type.include?("http://dbpedia.org/ontology/")
			}
			feature_vector
		end
		
	end
	
	class YagoExtractor	< FeatureExtractor
		
		def get_attributes
      return @attributes if @attributes
			yago_classes = []
			classes_query = "select distinct class from uri_classes
													where class like '%yago%'"
			rs = @repository.execute_query(classes_query)
			while rs.next do
				yago_classes << rs.getString(1)
			end
      @attributes = yago_classes.dup
			@attributes += yago_classes.map{|attr| attr.dup << "SE"}
		end
		
		def extract(sentence, include_response=false)
			attributes = get_attributes
			feature_vector = Array.new(attributes.size, 0)
			feature_vector[attributes.size - 1] = sentence.relation if include_response			
			sentence.principal_entity.types.each{|type|
        index = attributes.index(type)
        if index
          puts type
        end
				feature_vector[index] = 1 if index
			}
			sentence.secondary_entity.types.each{|type|
        index = attributes.rindex(type.dup<<"SE")
				feature_vector[index] = 1 if index
			}
			feature_vector
		end
		
	end
	
	class LexicalExtractor < FeatureExtractor
		
		def get_attributes
      return @attributes if @attributes      
			@attributes = @repository.find_words
      if @radical_extractor
        puts "RADICAL EXTRACTOR"
        @attributes.map!{|attr|@radical_extractor.extract_radical(attr.removeaccents)}.uniq!
      end
      @attributes
		end
		
		def extract(sentence, include_response = false)
      # puts "extracting feature for : #{sentence.relation}"
			attributes = get_attributes
      puts "LEXICAL ATTR SIZE: #{attributes.size}"
			feature_vector = Array.new(attributes.size, 0)
      puts "FEATURE VECTOR INITIALIZED"
			feature_vector[attributes.size - 1] = sentence.relation if include_response			
      # puts "STARTING FEATURE VECTOR SEARCH"
			sentence.radicals.each{|radical|
				index = attributes.index(radical.removeaccents)
        if index
          # puts "RADICAL: #{radical}"
          feature_vector[index] = 1
        end
			}
       puts "ENDING FEATURE VECTOR SEARCH"
      # puts "INSPECT #{feature_vector.inspect}"
			feature_vector
		end
		
	end
  
  class VerbsAndSubstantivesExtractor < FeatureExtractor
    require 'java'
    require 'lib/opennlp/opennlp-tools-1.5.0.jar'
    require 'lib/opennlp/lib/maxent-3.0.0.jar'
    require 'lib/opennlp/lib/jwnl-1.3.3.jar'
    
    java_import Java::java.io.FileInputStream
    java_import Java::opennlp.tools.postag.POSModel
    java_import Java::opennlp.tools.postag.POSTaggerME
    
		def initialize(repository)
			@repository = repository
      model_in = FileInputStream.new('lib/opennlp/models/en-pos-maxent.bin')
      @pos_model = POSModel.new(model_in)
      @pos_tagger = POSTaggerME.new(@pos_model)
		end
		
		def get_attributes
      attributes = @repository.find_words
			attributes.map{|attr| attr.stem}.uniq
		end
		
		def extract(sentence, include_response = false)
			attributes = get_attributes
			feature_vector = Array.new(attributes.size, 0)
			feature_vector[attributes.size - 1] = sentence.relation if include_response
      # puts "SENTENCE BEFORE CLEAN: #{sentence.text}"
      sentence.clean_text
      # puts "SENTENCE AFTER CLEAN: #{sentence.text}"
      tokens = sentence.tokenize
      pos_tags = @pos_tagger.tag(tokens)      
      for i in 0..tokens.size
        if !pos_tags[i].nil? && (pos_tags[i].include?('NN') || pos_tags[i].include?('VB'))
          puts "#{tokens[i]} : #{pos_tags[i]}"
          feature_vector[attributes.index(tokens[i].stem)] = 1 if attributes.index(tokens[i].stem)
        end
      end
			feature_vector
		end		
	end
  
  class ShortestPathExtractor  < FeatureExtractor
    attr_accessor :corref_analyser, :parser
		def initialize(repository, uri_pattern=nil)
      @repository = repository
      # @parser = NLP::StanfordDependencyParser.new('lib/stanford-parser-2012-03-09/englishPCFG.ser.gz')
      @restrictions = "from sentences s, sentence_paths sp where s.id = sp.stc_id"
      
		end
    
    def get_attributes
			@attributes ||= @repository.find_all_shortest_paths.flatten.map{|attr|        
        attr = "->" << attr if !attr.include?("-")          
        word = attr.gsub("->", "").gsub("<-", "")        
        attr.gsub(word, word.stem).downcase
      }.uniq
      @attributes
		end
    
    def select_subject(tdl)
      tdl.select{|td| td.relation.to_s.include?("subj")}
    end
    
    def calculate_shortest_path(sentence)
      puts "FINDING DEPEDENCY"
      tdl = @repository.find_dependency_list(sentence)
      puts "DEPEDENCY FOUND"
      ep = find_principal_entity(tdl)
      puts "EP: #{ep}"
      se = find_secondary_entity(tdl)
      sbj_td = select_subject(tdl).first
      if ep == nil && sbj_td != nil
        
        if sbj_td.gov.index < sbj_td.dep.index
          ep = sbj_td.gov
        else
          ep = sbj_td.dep
        end
      end
      if ep != nil && se != nil
      dijkstra = Graph::Dijkstra.new()
      # computing the undirected shortest path
      path, direction_hash = NLP.compute_shortest_path(tdl, ep, se, dijkstra)
      @repository.save_path(path.map{|node|direction_hash[node]+node.label.to_s}, sentence, "SHORTEST-PATH")
      FeatureExtraction.log(" SHORTEST PATH: #{path.map{|node|direction_hash[node]+node.label.to_s}.join}")      
      end
    end
    
    def find_principal_entity(tdl)
      principal_entity = nil
      tdl.each{|td| 
        if td.gov.label == "EP"
          principal_entity = td.gov
        elsif td.dep.label == "EP"
          principal_entity = td.dep
        end
      }
      principal_entity
    end
    
    def find_secondary_entity(tdl)
      secondary_entity = nil
      tdl.each{|td| 
        if td.gov.label == "SE2"
          secondary_entity = td.gov
        elsif td.dep.label == "SE2"
          secondary_entity = td.dep
        end
      }
      secondary_entity
    end
    
    def extract(sentence, include_response = false)
      attributes = get_attributes
      puts "ATTR SIZE: " + attributes.size.to_s
			feature_vector = Array.new(attributes.size, 0)
			feature_vector[attributes.size - 1] = sentence.relation if include_response
      puts "FINDING PATH"
      path = @repository.find_first_shortest_path(sentence)      
      path ||= calculate_shortest_path(sentence)
      puts "PATH: #{path.inspect}"
      puts "TRYING TO SET FEATURE"
      path.each{|word_and_direction|        
        word_and_direction = "->" << word_and_direction if !word_and_direction.include?("-")
        word_and_direction.downcase!
        word = word_and_direction.gsub("->", "").gsub("<-", "")        
        word_and_direction.gsub(word, word.stem)
        index = attributes.index(word_and_direction)
        puts "#{index}: "+word_and_direction
				feature_vector[index] = 1 if index        
			}
      puts "VECTOR SIZE: " + feature_vector.size.to_s
      puts "END TRYING TO SET FEATURE"
      feature_vector
      
    end
  end
  
  class ParseTreeExtractor  < FeatureExtractor
    attr_accessor :corref_analyser, :parser
		def initialize(repository, uri_pattern=nil)
      @repository = repository
      # @parser = NLP::StanfordDependencyParser.new('lib/stanford-parser-2012-03-09/englishPCFG.ser.gz')
      @restrictions = "from sentences s, sentence_paths sp where s.id = sp.stc_id"
		end
		
		def get_attributes
			@attributes ||= @repository.find_all_shortest_paths.flatten.map{|attr|        
        attr = "->" << attr if !attr.include?("-")          
        word = attr.gsub("->", "").gsub("<-", "")        
        attr.gsub(word, word.stem).downcase
      }.uniq
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
      text_cleaner = sentence.text_cleaner            
      text = sentence.text.dup
      label ||= sentence.secondary_entity.id.scan(/http:\/\/.*\/(.*)/).first.first.gsub("_", " ")
      sentence_markups = text.to_s.scan(/(\[\[([^\]]*)\]\])/)
      FeatureExtraction.log("SENTENCE: #{sentence.text}")
      FeatureExtraction.log("LABEL: #{label}")
      
      # Finding the secondary entity mention and substituting by the SE2 label
      sentence_markups.each{|markup|        
        if markup[1].split("|")[0] == label       
          text.gsub!(markup[0].to_s, "SE2") 
          FeatureExtraction.log("LABEL FOUND!: #{text}")
        else
          text.gsub!(markup[0].to_s, markup[1].split("|")[0]) 
          FeatureExtraction.log("LABEL NOT FOUND!: #{sentence_markups.inspect}")
        end
      }

      # First corref analysis, trying to find the title words quoted in text, like '''Deep Purple'''
      # this is faster than a sql query
      corref_label = @corref_analyser.pre_analyse(sentence)
      FeatureExtraction.log("CORREF PRE-ANALISYS RESULT!: #{corref_label}")
      
      text.gsub!(/#{corref_label}/i, "EP") if corref_label
      FeatureExtraction.log("SCAN RESULT!: #{text.scan(/#{corref_label}/i)}")
      FeatureExtraction.log("TEXT!: #{text}")
      
      # next corref try, query in the support database
      corref_label ||= @repository.find_corref(sentence.id)
      FeatureExtraction.log("CORREF DATABASE SEARCH RESULT: #{corref_label}")
      if(corref_label.nil? && !@corref_analyser)
        raise("Couldn't find the correference for the principal entity!")
      end
      sentence.text = text
      sentence.clean_text
      FeatureExtraction.log("SENTENCE FOLLOWING TO THE PARSER: #{sentence.text}")
      
      # Computing the dependency list, with govs and deps
      tdl = @parser.compute_dependency_list(sentence)
      FeatureExtraction.log("DEPENDENCY LIST: #{tdl.map{|dp| dp.relation + ":" + dp.gov.label + ":" + dp.dep.label}.inspect}")
      
      
      tdl.each{|td| 
        principal_entity_node = td.dep if td.dep.label.include?("EP")
        principal_entity_node = td.gov if td.gov.label.include?("EP")
        secondary_entity_node = td.dep if td.dep.label.include?("SE2")
        secondary_entity_node = td.gov if td.gov.label.include?("SE2")        
      }
      FeatureExtraction.log("PRINCIPAL NODE: #{principal_entity_node}")
      FeatureExtraction.log("SECONDARY NODE: #{secondary_entity_node}")      
      
      # finding only the subjects
      sentence_subjects = NLP::find_subjects(tdl)
      FeatureExtraction.log("SUBJECTS: #{sentence_subjects.inspect}")
      # trying to find a subject that is the correference for the principal entity
      principal_entity_node ||= sentence_subjects.select{|subj| subj.label.include?(corref_label)}.first if corref_label
      
      # the deepest corref analysis, that takes account the most frequent pronoums.
      principal_entity_node ||= @corref_analyser.analyse(sentence, sentence_subjects, @repository)
      FeatureExtraction.log("PRINCIPAL NODE AFTER CORREF ANALYSIS: #{principal_entity_node}")
      
      # if the two entities mentions were found, compute the shortest path in the dependency graph
      if (principal_entity_node && secondary_entity_node)
        corref_label ||= principal_entity_node.label
        principal_entity_node.label = "EP"
        FeatureExtraction.log("SENTENCE: #{sentence.text}")
        FeatureExtraction.log(" CORREF: #{corref_label} -> #{corref_label == 'NDA'}")
        FeatureExtraction.log(" SUBJECTS: #{sentence_subjects.map{|s|s.to_s}.inspect}")
        FeatureExtraction.log(" NODES: #{corref_label}, #{label}")
        
        # the shortest path strategy: Dijkstra
        dijkstra = Graph::Dijkstra.new()
        # computing the undirected shortest path
        path, direction_hash = NLP.compute_shortest_path(tdl, principal_entity_node, secondary_entity_node, dijkstra)
        @repository.save_path(path.map{|node|direction_hash[node]+node.to_s}, sentence, "SHORTEST-PATH")
        FeatureExtraction.log(" SHORTEST PATH: #{path.map{|node|direction_hash[node]+node.to_s}.join}")
        FeatureExtraction.log("")      
      end
      path.nil??nil:path.map{|node|direction_hash[node]+node.label.to_s}
    end
    
		def extract(sentence, include_response = false)
      attributes = get_attributes
      puts "ATTR SIZE: " + attributes.size.to_s
			feature_vector = Array.new(attributes.size, 0)
			feature_vector[attributes.size - 1] = sentence.relation if include_response
      puts "FINDING PATH"
      path = @repository.find_first_shortest_path(sentence)      
      path ||= calculate_shortest_path(sentence)
      puts "PATH: #{path.inspect}"
      puts "TRYING TO SET FEATURE"
      path.each{|word_and_direction|        
        word_and_direction = "->" << word_and_direction if !word_and_direction.include?("-")
        word_and_direction.downcase!
        word = word_and_direction.gsub("->", "").gsub("<-", "")        
        word_and_direction.gsub(word, word.stem)
        index = attributes.index(word_and_direction)
        puts "#{index}: "+word_and_direction
				feature_vector[index] = 1 if index        
			}
      puts "VECTOR SIZE: " + feature_vector.size.to_s
      puts "END TRYING TO SET FEATURE"
      feature_vector
      
		end
	end
  
  class GovNodesExtractor < FeatureExtractor
    attr_accessor :corref_analyser, :parser
		def initialize(repository, uri_pattern=nil)
      @repository = repository
      # @parser = NLP::StanfordDependencyParser.new('lib/stanford-parser-2012-03-09/englishPCFG.ser.gz')
      @restrictions = "from sentences s, sentence_paths sp where s.id = sp.stc_id"
      
		end
    
    def get_attributes
			@attributes ||= @repository.find_all_gov_nodes.map{|attr| attr.split("-")[0].removeaccents.downcase << "_gov"}.uniq
      @attributes
		end
    
    def get_gov_nodes(sentence)
      puts "FINDING DEPEDENCY"
      tdl = @repository.find_dependency_list(sentence)
      puts "DEPEDENCY FOUND: #{tdl.size}"
      tdl.map{|td| td.gov.label.removeaccents.downcase << "_gov"}      
    end
    
    def extract(sentence, include_response = false)
      attributes = get_attributes
      puts "ATTR SIZE: " + attributes.size.to_s
			feature_vector = Array.new(attributes.size, 0)
			feature_vector[attributes.size - 1] = sentence.relation if include_response
      puts "FINDING PATH"
      gov_nodes = get_gov_nodes(sentence)
      gov_nodes.each{|gov_node|                
        index = attributes.index(gov_node)
        puts "#{index}: "+gov_node
				feature_vector[index] = 1 if index        
			}
      puts "VECTOR SIZE: " + feature_vector.size.to_s
      puts "END TRYING TO SET FEATURE"
      feature_vector      
    end
  end
end