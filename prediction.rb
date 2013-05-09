require './model.rb'
require './spotlight_endpoint.rb'
require './feature_extraction_prediction.rb'
require './dataset_generation'
require './classification.rb'
require 'jruby_threach'
require 'cgi'
require 'httparty'
require 'json'
require 'addressable/uri'    
module Prediction
  
  def self.recognize_entities_from_google_dataset()
    
    @google_dataset_path = "datasets/google-institution.json"
    ConfigModule::Config.new    
    require 'json'
    rep = ConfigModule.config.sentences_repository
    json_lines = File.readlines(@google_dataset_path)
    json_string = File.read(@google_dataset_path)
    parsed_instances = []
    i = 0
    current_instance = nil
    json_lines.each{|line| parsed_instances << [JSON.parse(line), line] if line.scan(/(\[\[([^\]]*)\]\])/).empty?}
    @removed_lines = []
    begin
      i = 0
      parsed_instances.threach(20){|instance|
 
#        parsed_instances.each{|instance|
        current_instance = instance
        subject_freebase_id = instance.first["sub"]
#        if(!rep.find_entity(subject_freebase_id).nil?)
#          next
#        end
        object_freebase_id = instance.first["obj"]
        entity1 = find_freebase_entity(subject_freebase_id)
        if(!entity1)
          @removed_lines << instance.last
          next
        end
        if(entity1.types.empty?)
          entity1.types = ["http://dbpedia.org/ontology/Person"]
        end
        
        entity2 = find_freebase_entity(object_freebase_id)
        if(!entity2)
          @removed_lines << instance.last
          next
        end
        if(entity2.types.empty?)
          entity2.types = ["http://dbpedia.org/ontology/University"]
        end
        if(entity1.label.empty?)
          wikipedia_url = instance.first["evidences"].first["url"]
          entity1.label = wikipedia_url.scan(/http:\/\/.*\/(.*)/).first.first.gsub("_", " ")
        end
        snippet = instance.first["evidences"].first["snippet"]
        
        entity1.snippet = snippet
        i += 1
        puts "INDEX: #{i}"
        preprocessor = ConfigModule::config.preprocessor
        
        sentences = preprocessor.preprocess(snippet)
        puts "SENTENCES SIZE: #{sentences.size}"
        sentence = nil
        corref_secondary_entity = ""
        sentences.each{|stc|          
          label = entity2.label
          puts "SECOND ENTITY LABEL: #{label}"
          corref_found = stc.text.scan(/#{label}/i)
          if(!corref_found.empty?)
            puts "  SE CORREF FOUND DIRECTLY: #{label}"
            corref_secondary_entity = label
            sentence = stc
          end
        }        
        
#        corref_secondary_entity = find_secondary_entity(snippet, entity2)
#        puts "Terminei sec entity finding"
#        corref_principal_entity = find_principal_entity_corref(snippet, entity1, entity2)
        if(sentence)
          corref_principal_entity = find_principal_entity_corref(sentence.text, entity1, entity2)
          puts sentence.text
          puts "CORREF FOUND: #{corref_principal_entity}"
          puts "CORREF FOUND: #{corref_secondary_entity}"
          sentence.principal_entity = entity1
          sentence.secondary_entity = entity2
        else
          puts "No COrref found"
          @removed_lines << instance.last
          next
        end
      
        corref_snippet = " " << sentence.text.dup
        entity1_corref = corref_snippet.scan(/ #{corref_principal_entity} /i).first
        entity2_corref = corref_snippet.scan(/#{corref_secondary_entity}/i).first
        puts "ET1 CORREF FOUND: #{entity1_corref}"
        puts "ET2 CORREF FOUND: #{entity2_corref}"
        if(corref_principal_entity.to_s.empty? || corref_secondary_entity.to_s.empty? || !entity1_corref || !entity2_corref)
          @removed_lines << instance.last
          next
        end
        corref_snippet = corref_snippet.gsub(entity1_corref, " [[#{entity1_corref.strip}-EP]] ") if !corref_principal_entity.empty?
        corref_snippet.gsub!(entity2_corref, "[[#{entity2_corref}-SE]]") if !corref_secondary_entity.empty?
        puts corref_snippet
#        if(i == 2 || i == 200 || 
#        i == 100 || i == 500 ||
#        i == 700 || i == 1000 || i == 2000 || i == 1500 || i == 1700 || i= 2000 ||i =2500 || i ==3000 || i ==4000 || i ==4500|| i ==5000 || i ==6000|| i ==7000)
#          File.open(@google_dataset_path, 'w'){|f|f.write(json_string)}
#        end
        sentence.text = corref_snippet
        sentence.offset = 0
        rep.save_unclassified_sentence(sentence, "http://dbpedia.org/ontology/almaMater")
        @removed_lines << instance.last
        puts 
      }
    rescue Exception => e
      puts "EXCEPTION OCCURED: #{e}"
      @removed_lines << instance.last
      @removed_lines.each{|line| json_string.gsub!(line)}
      File.open(@google_dataset_path, 'w'){|f|f.write(json_string)}
#      recognize_entities_from_google_dataset          
    end
  end
  
  def self.find_principal_entity_corref(snippet, entity1, entity2)
    label = entity1.label
    corref = ""
#    puts "SNIPPET PRINCIPAL ENTITY: #{snippet}"
    corref_found = snippet.scan(/#{label}/i)
    if(!corref_found.empty? && snippet.include?(corref_found.first))
#      puts "  CORREF FOUND DIRECTLY: #{label}"
      corref = corref_found.first
    else
      text_cleaner = ConfigModule.config.text_cleaner
      
      corpus = ConfigModule.config.corpus
      
      corref_analyser = ConfigModule.config.corref_analyser      
      
      article_text = corpus.find_entity_article(label.gsub(" ", "_"))
#      puts "passei por aqui"
      clean_text = text_cleaner.clean(article_text)
#      puts "passei por clean text"
      paragraphs = clean_text.split("\n\n")
#      puts "passei por split"
      wikipedia_snippet = paragraphs[0] || snippet
      sentence = create_sentence(snippet, entity1, entity2)
#      puts "passei por create sentence"
      corref = corref_analyser.pre_analyse(sentence)
      puts "    CORREF IN PREANALYSE #{corref}"
#      puts "passei por pre analyse"
      if(corref.to_s.strip.empty? || snippet.scan(/#{corref.to_s}/i).size == 0 )        
        corref = corref_analyser.get_most_frequent_pronoun(snippet, entity2.label)        
        puts "Try to get most frequent pronoun: #{corref}"
      end              
      corref
    end    
#    puts "  CORREF: #{corref}"
    corref
  end
  
  def self.select_sentence_with_entity2(snippet, entity2)
    
  
  end
    
  def self.find_wiki_link_to_entity(entity, text)
    sentence_markups = text.to_s.scan(/(\[\[([^\]]*)\]\])/)
    
    link_to_target = sentence_markups.select{|markup|  
      markup[1].split("|")[0] == entity.label
    }
    link_to_target
  end
  
  def self.find_secondary_entity(snippet, entity2, wikipedia_text)     

      paragraphs = wikipedia_text.split("\n\n")
      snippet = paragraphs[0]
      if snippet
        link = find_wiki_link_to_entity(entity2, snippet)
        puts "SECONDARY ENTITY REF: #{link}"
        corref = link
      end
      
    
    puts "Fim Correr Sec Entity"
    corref
  end
  
  def self.find_freebase_entity(freebase_uri)
    api_key = "AIzaSyD3KzJG4tO_KVaYPwQ7eDBROYgh2xcm_dY"
    types = []
    url = Addressable::URI.parse('https://www.googleapis.com/freebase/v1/topic' + freebase_uri)
    url.query_values = 
    {
            'key'=> api_key
    }
    
    json_entity = HTTParty.get(url, :format => :json)
    return nil if !json_entity
    freebase_name = json_entity['property']['/type/object/name']
    label = "No Label"
    label = freebase_name['values'][0]['value'] if freebase_name 
    notable_types = json_entity['property']['/common/topic/notable_types'] 
    types = notable_types['values'] if notable_types
    
    dbpedia_types = types.map{|type| 
      "http://dbpedia.org/ontology/#{type["text"].split(" ").map{|type_part|type_part.capitalize}.join}"      
    }    
    Model::Entity.new(freebase_uri, label, dbpedia_types, "")
  end
  
  def self.create_sentence(text, entity1, entity2)
    config = ConfigModule.config
    sentence = Model::Sentence.new()
    sentence.text = text
    sentence.radical_extractor = config.radical_extractor
    sentence.text_cleaner = config.text_cleaner
    sentence.tokenizer = config.tokenizer
    sentence.principal_entity = entity1
    sentence.secondary_entity = entity2
    sentence
  end
  def self.find_sentences()
    
  end
  def self.generate_google_test_set
      @google_dataset_path = "datasets/google_place_of_birth.json"
    ConfigModule::Config.new    
    require 'json'
    rep = ConfigModule.config.sentences_repository
    json_lines = File.readlines(@google_dataset_path)
    json_string = File.read(@google_dataset_path)
    parsed_instances = []
    i = 0
    current_instance = nil
    json_lines.each{|line| parsed_instances << [JSON.parse(line), line] if !line.scan(/(\[\[([^\]]*)\]\])/).empty?}
    @removed_lines = []
    
    feature_matrix = []
    header = FeatureExtractionPrediction.get_attributes.map{|attr| attr.gsub('"', '\"')}
#    header = File.readlines("prediction_header.txt").map{|attr| attr.gsub("\n", "").gsub('"', '\"')}
    types = ["rel"]
    types += File.readlines("90_dbpedia_properties_list.txt").map{|rel|rel.gsub("\n", "")}
    feature_matrix << header
    i = 0
#      parsed_instances.threach(20){|instance|
      data_matrix = []    
      parsed_instances[0..3800].each{|instance|
        current_instance = instance
        subject_freebase_id = instance.first["sub"]
  
        object_freebase_id = instance.first["obj"]
        entity1 = Model::Entity.new(subject_freebase_id, subject_freebase_id, ["http://dbpedia.org/ontology/Person"], "")        
        
        entity2 = Model::Entity.new(object_freebase_id, object_freebase_id, [], "")      
        
        entity2.types << "http://dbpedia.org/ontology/PopulatedPlace"
        entity2.types << "http://dbpedia.org/ontology/Settlement"
        entity2.types.uniq!
        if(entity1.label.empty?)
          wikipedia_url = instance.first["evidences"].first["url"]
          entity1.label = wikipedia_url.scan(/http:\/\/.*\/(.*)/).first.first.gsub("_", " ")
        end
        snippet = instance.first["evidences"].first["snippet"]
        sentence = nil
        preprocessor = ConfigModule.config.preprocessor
        sentences = preprocessor.preprocess(snippet)
        sentences.each{|stc|
          copy_of_text = stc.text.dup
          puts copy_of_text
          named_entities = copy_of_text.scan(/(\[\[([^\]]*)\]\])/)
          
          next if named_entities.select{|match|match.first.include?("EP")}.empty?
          
          principal_entity = named_entities.select{|match|match.first.include?("EP")}.first.first
          flag = false
          copy_of_text.gsub!(principal_entity){|m|
            result = m
            if(!flag)        
              flag = true
              result = "EP"
            end
            result
          }
          next if named_entities.select{|match|match.first.include?("SE")}.empty?
          
          secondary_entity = named_entities.select{|match|match.first.include?("SE")}.first.first
          flag = false
          copy_of_text.gsub!(secondary_entity){|m|
            result = m
            if(!flag)        
              flag = true
              result = "SE2"
            end
            result
          }
          if(copy_of_text.include?("EP") && copy_of_text.include?("SE2"))
            stc.text = copy_of_text
            sentence = stc
          end
        }
        
        if(sentence.nil?)
          puts "NOT IN THE SAME SENTENCE"
          next
        end
        puts sentence.text
        i += 1
        config = ConfigModule.config
        
        
        sentence.radical_extractor = config.radical_extractor
        sentence.text_cleaner = config.text_cleaner
        sentence.tokenizer = config.tokenizer
        sentence.principal_entity = entity1
        sentence.secondary_entity = entity2
        
        data_matrix = [FeatureExtractionPrediction.extract(sentence)]    
        
        puts "MATRIX SIZE: #{data_matrix.size}"
    #    puts "Matrix features captured: " + data_matrix.select{|f|f==1}.size.to_s
        
        
        feature_matrix += data_matrix
#        puts "generating dataset" + feature_matrix[1].inspect.to_s
       
     
    }
    dataset_format = ConfigModule.config.dataset_format
    dataset_path = DatasetGeneration.generate(feature_matrix, dataset_format, types)
#    File.open("trainning_data/instances.arff", 'w'){|f| 
#      f.write(File.read("header.arff") << File.read("trainning_data/unpredicted_instances.arff"))
#    }
     
#    classifier = Classification::LibLINEARClassifier.new()
#    prediction_result = classifier.predict
#    puts prediction_result.inspect
end

  def self.generate_google_institution_test_set

    ConfigModule::Config.new    

    rep = ConfigModule.config.sentences_repository

    
    i = 0    
    feature_matrix = []
    header = FeatureExtractionPrediction.get_attributes.map{|attr| attr.gsub('"', '\"')}
#    header = File.readlines("prediction_header.txt").map{|attr| attr.gsub("\n", "").gsub('"', '\"')}
    types = ["rel"]
    types += File.readlines("90_dbpedia_properties_list.txt").map{|rel|rel.gsub("\n", "")}
    feature_matrix << header
    i = 0
#      parsed_instances.threach(20){|instance|
      data_matrix = []
      sentences = rep.find_all_sentences
        sentences.each{|stc|
          copy_of_text = stc.text.dup
          puts copy_of_text
          named_entities = copy_of_text.scan(/(\[\[([^\]]*)\]\])/)
          
          next if named_entities.select{|match|match.first.include?("EP")}.empty?
          
          principal_entity = named_entities.select{|match|match.first.include?("EP")}.first.first
          flag = false
          copy_of_text.gsub!(principal_entity){|m|
            result = m
            if(!flag)        
              flag = true
              result = "EP"
            end
            result
          }
          next if named_entities.select{|match|match.first.include?("SE")}.empty?
          
          secondary_entity = named_entities.select{|match|match.first.include?("SE")}.first.first
          flag = false
          copy_of_text.gsub!(secondary_entity){|m|
            result = m
            if(!flag)        
              flag = true
              result = "SE2"
            end
            result
          }
          if(copy_of_text.include?("EP") && copy_of_text.include?("SE2"))
            stc.text = copy_of_text
            sentence = stc
          end
        
        
        if(sentence.nil?)
          puts "NOT IN THE SAME SENTENCE"
          next
        end
        puts sentence.text
        i += 1
        config = ConfigModule.config
        
        
                
        data_matrix = [FeatureExtractionPrediction.extract(sentence)]    
        
        puts "MATRIX SIZE: #{data_matrix.size}"
    #    puts "Matrix features captured: " + data_matrix.select{|f|f==1}.size.to_s
        
        
        feature_matrix += data_matrix
#        puts "generating dataset" + feature_matrix[1].inspect.to_s
       }
     
    
    dataset_format = ConfigModule.config.dataset_format
    dataset_path = DatasetGeneration.generate(feature_matrix, dataset_format, types)
#    File.open("trainning_data/instances.arff", 'w'){|f| 
#      f.write(File.read("header.arff") << File.read("trainning_data/unpredicted_instances.arff"))
#    }
     
#    classifier = Classification::LibLINEARClassifier.new()
#    prediction_result = classifier.predict
#    puts prediction_result.inspect
  end
  def self.predict(text)
    config = ConfigModule::Config.new
    preprocessor = config.preprocessor
    entities = SpotlightEndpoint.recognize_entities_from_text(text)
    possible_related_entities_hash = {}
    entities.size.times do |index|
      entity = entities[index]      
      possible_related_entities_hash[entity] = entities[index+1, entities.size]      
    end
    data_matrix = []
    
    possible_related_entities_hash.each{|entity, related_entities|
      
      related_entities.each{|related|
        copy_of_text = text.dup
        puts entities.first.inspect
        copy_of_text.gsub!(entity.surface_form, "EP")
        puts copy_of_text
        copy_of_text.gsub!(related.surface_form, "SE2")
        puts copy_of_text
        
        sentence = Model::Sentence.new()
        sentence.text = copy_of_text
        sentence.radical_extractor = config.radical_extractor
        sentence.text_cleaner = config.text_cleaner
        sentence.tokenizer = config.tokenizer
        sentence.principal_entity = entity
        sentence.secondary_entity = related
        
        data_matrix << FeatureExtractionPrediction.extract(sentence)
      }
    }
    
    
    
#    puts "Matrix features captured: " + data_matrix.select{|f|f==1}.size.to_s
    
    dataset_format = config.dataset_format
    feature_matrix = []
    header = FeatureExtractionPrediction.get_attributes.map{|attr| attr.gsub('"', '\"')}
#    header = File.readlines("prediction_header.txt").map{|attr| attr.gsub("\n", "").gsub('"', '\"')}
    types = ["rel"]
    types += File.readlines("90_dbpedia_properties_list.txt").map{|rel|rel.gsub("\n", "")}
    feature_matrix << header
    feature_matrix += data_matrix
    puts "generating dataset" + feature_matrix[1].inspect.to_s
    dataset_path = DatasetGeneration.generate(feature_matrix, dataset_format, types)
    
    File.open("trainning_data/instances.arff", 'w'){|f| 
      f.write(File.read("header.arff") << File.read("trainning_data/unpredicted_instances.arff"))
    }
    
    classifier = Classification::LibLINEARClassifier.new()
    prediction_result = classifier.predict
    puts prediction_result.inspect
  end
  
end