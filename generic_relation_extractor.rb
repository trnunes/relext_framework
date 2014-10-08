require 'rubygems'
require 'yaml'
require './model.rb'
require './config.rb'
require './preprocessing.rb'
require './filtering.rb'
require './feature_extraction.rb'
require './generic_dataset_generation'
require './classification.rb'
require './repositories.rb'
require './corpus.rb'
require './bow_builder.rb'
require './nlp.rb'
require './generic_feature_extraction.rb'
module GenericRelationExtractor
  include Model
  
  LOG = './log/extracting_features.log'
  File.open(LOG, 'w'){|f| f.write("")}
  
  def self.log(msg)
      File.open(LOG, 'a'){|f| f.write(msg << "\n")}
  end
  def self.init(database_address)

    @@tokenizer ||= Preprocessing::DefaultTokenizer.new()
    @@radical_extractor ||= Preprocessing::DefaultRadicalExtractor.new()
    @@sentences_repository ||= Repositories::SingleTableRepository.new("jdbc:mysql://#{database_address}:3306/pedro_dataset?user=root&password=1234")
    normalizer = Preprocessing::DefaultTokenNormalizer.new()
    GenericFeatureExtraction.feature_repo= @@sentences_repository
    lexical_extractor = GenericFeatureExtraction::LexicalExtractor.new()
    entity_types_repository = @@sentences_repository
    lexical_extractor.tokenizer = @@tokenizer
    lexical_extractor.normalizer = @@radical_extractor
    
    @@parser ||= NLP::StanfordDependencyParser.new("lib/stanford-parser-2012-03-09/englishPCFG.ser.gz")
    entity_types_extractor = GenericFeatureExtraction::EntityTypesExtractor.new()   
    
    shortest_path_extractor = GenericFeatureExtraction::ShortestPathExtractor.new()
    
    shortest_path_extractor.dependency_list_finder = lambda {|sentence|
      dep_list = @@sentences_repository.find_dependency_list(sentence)

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
  
  def self.extract_features(offset, limit)
    begin

        sentences = @@sentences_repository.find_sentences(offset, limit)
        filtered_sentences = Filtering.do_filter(sentences)
      
        filtered_sentences.each{|sentence|
            GenericFeatureExtraction.extract(sentence)
        }

        return ["SUCCESS"]
    rescue Exception => e
        log(e.to_s + " OFFSET: #{offset}")
        return ["FAILURE", e]
    end
  end

  def self.generate_arff
      arffFormatGenerator = GenericDatasetGeneration::ARFFormat.new("property", "./test_dataset.arff")
      sentence_repository = @@sentences_repository
      relations = ["/editor", "/publisher"]
      data_matrix = []

      relations.each{|relation|
          trainning_set_total_instances = sentence_repository.count_instances(relation)

          sentences = sentence_repository.find_sentences(@@offset, @@limit)
          sentences.each{|sentence|
              feature_array = []
              feature_array = sentence_repository.find_features(sentence.id)
              feature_array << sentence.relation

              
              arffFormatGenerator.add_instance(feature_array)

          }
      }
      arffFormatGenerator.generate
      
  end

#    begin
      
#      self.init
#      self.generate_dataset(1)
#      return "SUCCESS"
#    rescue
#        return "FAIL"
#    end
#  self.generate_arff
end