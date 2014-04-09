require 'rubygems'
require 'yaml'
require './model.rb'
require './config.rb'
require './preprocessing.rb'
require './filtering.rb'
require './feature_extraction.rb'
require './dataset_generation'
require './classification.rb'
require './repositories.rb'
require './corpus.rb'
require './bow_builder.rb'
require './nlp.rb'
require './generic_feature_extraction.rb'
module GenericRelationExtractor
	include Model
  
  def self.init
    @@tokenizer = Preprocessing::DefaultTokenizer.new()
    @@radical_extractor = Preprocessing::DefaultRadicalExtractor.new()
    @@sentences_repository = Repositories::SingleTableRepository.new("jdbc:mysql://localhost:3306/pedro_sentences_db?user=root&password=1234")
    normalizer = Preprocessing::DefaultTokenNormalizer.new()
    GenericFeatureExtraction.feature_repo= @@sentences_repository
    lexical_extractor = GenericFeatureExtraction::LexicalExtractor.new()
    entity_types_repository = @@sentences_repository
    lexical_extractor.tokenizer = @@tokenizer
    lexical_extractor.normalizer = @@radical_extractor
    
    @@parser = NLP::StanfordDependencyParser.new("lib/stanford-parser-2012-03-09/englishPCFG.ser.gz")
    entity_types_extractor = GenericFeatureExtraction::EntityTypesExtractor.new()   
    
    shortest_path_extractor = GenericFeatureExtraction::ShortestPathExtractor.new()
    shortest_path_extractor.dependency_list_finder = lambda {|sentence|
      dep_list = @@sentences_repository.find_dependency_list(sentence)
      puts "PARSING #{sentence.text} #{dep_list.empty?}"
      if(dep_list.empty?)
        dep_list = @@parser.compute_dependency_list(sentence)
        @@sentences_repository.save_dependency_list(dep_list, sentence)      
      end
      dep_list
    }
     
    markup_recognizer = lambda {|text| text.scan(/(<([^<]*)\/([^<]*)>)/)}
    
    shortest_path_extractor.primary_entity_recognizer = lambda {|sentence|
      markup_recognizer.call(sentence.text)[0]
    }
    
    shortest_path_extractor.secondary_entity_recognizer = lambda {|sentence|
      markup_recognizer.call(sentence.text)[1]
    }
        
   GenericFeatureExtraction.add_extractor(lexical_extractor)
   GenericFeatureExtraction.add_extractor(shortest_path_extractor)
   GenericFeatureExtraction.add_extractor(entity_types_extractor)
  end
  
  def self.generate_dataset(percentage)
    sentence_repository = @@sentences_repository
    relations = ["/editor"]
    data_matrix = []
    puts "RELATIONS SIZE: #{relations.size}"
    relations.each{|relation|
      trainning_set_total_instances = sentence_repository.count_instances(relation) * percentage
      puts "QTD Novamente: #{trainning_set_total_instances}"
      sentences = sentence_repository.find_sentence_by_relation(relation, trainning_set_total_instances.to_i)
      filtered_sentences = Filtering.do_filter(sentences)
      
       
      # puts sentences.inspect
      i = 0
      filtered_sentences.each{|sentence|          
        GenericFeatureExtraction.extract(sentence)
                
      }      
    }
    # attributes = sentences_repository.find_feature_set
    # feature_vector = Array.new(attributes.size + 1, 0)
    # feature_vector[attributes.size - 1] = sentence.relation
    # dataset_path = DatasetGeneration.generate(feature_matrix, dataset_format)
  end
  
  self.init
  self.generate_dataset(0.5)  

end