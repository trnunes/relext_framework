require 'rubygems'
require 'yaml'
require 'jruby_threach'
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
require './prediction.rb'
require 'information_extraction.rb'
require './feature_extraction_prediction.rb'
module RelationExtractor
	include Model
  
  def evaluate_corref_strategies
    
  end
  
  def self.mount_bow
    config = ConfigModule::Config.new
    sentence_repository = config.sentences_repository
    b = BOWBuilder::WikipediaBOW.new()
    b.get_words(sentence_repository)    
  end
  
  
  def self.test_gov_extractor
    config = ConfigModule::Config.new
    corpus = config.corpus
    corref_analyser = InformationExtraction::WikipediaCorreferenceAnalyser.new(corpus)    
    sentence_repository = config.sentences_repository
    sentences = sentence_repository.find_sentence_by_relation("http://dbpedia.org/ontology/album", 5, 0)
    gov_extractor = FeatureExtraction::GovNodesExtractor.new(sentence_repository)
    gov_extractor.corref_analyser = corref_analyser
    gov_extractor.radical_extractor = config.radical_extractor
    gov_extractor.parser = NLP::DepPatternDependencyParser.new('')
    sentences.each{|sentence|
      gov_extractor.extract(sentence)
    }
  end
  
  def self.compute_dep_list_nyt
    config = ConfigModule::Config.new
    relations = config.relations_hash
    sentence_repository = config.sentences_repository
    @parser = config.parser
    @corref_analyser = config.corref_analyser
    
    relations.each{|relation, offset|
      
      
      sentences = sentence_repository.find_sentence_by_relation_and_offset(relation, 0)
      puts sentences.inspect
      sentences.each{|sentence|
        tdl = @parser.compute_dependency_list(sentence)
        sentence_repository.save_dependency_list(tdl, sentence)    
      }
    }
    
  end
  
  def self.compute_dep_list
    config = ConfigModule::Config.new
    relations = config.relations_hash
    sentence_repository = config.sentences_repository
    @parser = config.parser
    @corref_analyser = config.corref_analyser
    
    relations.each{|relation, offset|
      offset = sentence_repository.find_last_dep_list_offset(relation)
      puts "OFFSET: #{offset}"
      sentences = sentence_repository.find_sentence_by_relation_and_offset(relation, offset)
      puts "QTD: #{sentences.size}" 
      sentences.each{|sentence|
        if sentence.text.split(" ").size >= 80
          puts "GRANDE PRA KCT!!!"
          next
        end
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
        
        sentence.text = text
        sentence.clean_text
        FeatureExtraction.log("SENTENCE FOLLOWING TO THE PARSER: #{sentence.text}")
        # puts "BEGIN PARSING"
        tdl = @parser.compute_dependency_list(sentence)
        # puts "END PARSING"
        FeatureExtraction.log("DEPENDENCY LIST: #{tdl.map{|dp| dp.relation + ":" + dp.gov.label + ":" + dp.dep.label}.inspect}")
        sentence_subjects = NLP::find_subjects(tdl)
        FeatureExtraction.log("SUBJECTS: #{sentence_subjects.inspect}")
        # trying to find a subject that is the correference for the principal entity
        principal_entity_node ||= sentence_subjects.select{|subj| subj.label.include?(corref_label)}.first if corref_label
        
        # the deepest corref analysis, that takes account the most frequent pronoums.
        principal_entity_node ||= @corref_analyser.analyse(sentence, sentence_subjects, @repository)
        FeatureExtraction.log("PRINCIPAL NODE AFTER CORREF ANALYSIS: #{principal_entity_node}")
        
        principal_entity_node.label = "EP" if !principal_entity_node.nil?
        sentence_repository.save_dependency_list(tdl, sentence)    
      }
    }
    

  end
  
  def self.extract_portuguese
    config = ConfigModule::Config.new
    sentence_repository = config.sentences_repository
    sentences = sentence_repository.find_sentence_by_relation("http://dbpedia.org/ontology/album", 5, 0)
    sentences.each{|stc|
      text = stc.clean_text
      text << "." if text[text.size - 1].chr != "."
      File.open('input.txt', 'w'){|f| f.write(text << "\n")}
      parse_string = %x[./lib/DepPattern-2.1/dp.sh -a treetagger pt input.txt]
      puts "SENTENCE: " + text
      lines = parse_string.split("\n")
      lines[0] = nil
      lines.compact!
      dep = gov = relation = ""
      dep_list = lines.map{|dep_string| 
        dep_array = dep_string.gsub(/[\(\)]/, "").split(';')        
        if (dep_array[0] != nil && dep_array[1] != nil && dep_array[2] != nil)
          relation = dep_array[0]
          gov = dep_array[1]
          dep = dep_array[2]
          puts "------------------------------X--------------------------------------"
          puts "RELATION: " + relation
          puts "GOV: " + gov
          puts "DEP: " + dep
          gov = NLP::Node.new(gov.split("_")[0], gov.split("_")[2])
          dep = NLP::Node.new(dep.split("_")[0], dep.split("_")[2])        
          NLP::Dependency.new(gov,dep,relation)
        end
      }.compact
      puts dep_list.size
      puts dep_list.inspect
    }
  end
  
  def self.corref
    config = ConfigModule::Config.new
    
    sentence_repository = config.sentences_repository
    corpus = config.corpus
    preprocessor = config.preprocessor
    ext = FeatureExtraction::ParseTreeExtractor.new(sentence_repository)
    ext.parser = NLP::DepPatternDependencyParser.new('')
    sentences = sentence_repository.find_sentence_by_relation("http://dbpedia.org/ontology/album", 2, 0)
    corref_analyser = InformationExtraction::WikipediaCorreferenceAnalyser.new(corpus)
    ext.corref_analyser = corref_analyser
    count = 0
    sentences.each{|stc|
      count +=1
      puts "BEGIN EXTRACTING"
      ext.extract(stc)
      # corref_analyser.pre_analyse(stc)
      puts "BEGIN INSERTING CORREFERENCE"
      # sentence_repository.insert_corref(c, stc.id) if !c.to_s.empty?
      puts "END EXTRACTING: #{count}"
    }
    puts count
  end
  
  def self.find_test_sentences
	  entities = ["http://dbpedia.org/resource/Stevie_Nicks"]
	  config = ConfigModule::Config.new
    
	  relations = config.relations_hash
    relations_repository = config.relations_repository
    sentences_repository = config.sentences_repository
    corpus = config.corpus
    offset = 0    
    limit = 2000
    preprocessor = config.preprocessor
	  entities.each{|entity|
		  article = corpus.find_entity_article(entity)
		  article_sentences = preprocessor.preprocess(article).map{|sentence|        
			  sentence.principal_entity = entity
			  sentence.offset = 0			
			  sentences_repository.save_sentence(sentence)
        sentence_markups = sentence.text.to_s.scan(/(\[\[([^\]]*)\]\])/)
              
        link_to_target = sentence_markups.select{|markup|  
          markup[1].split("|")[0] == label
        }              
        stc if !link_to_target.empty?
      }      
		} 
  end
  
  def self.mine_examples
    config = ConfigModule::Config.new
    relations = config.relations_hash
    relations_repository = config.relations_repository
    sentences_repository = config.sentences_repository
    corpus = config.corpus
    offset = 0    
    limit = 2000
    preprocessor = config.preprocessor
    true_relations = [1]
    while(true) do
      begin 
        relations.threach(relations.size){|relation, offset|
          while(!true_relations.empty?) do
            true_relations = relations_repository.find_true_relations(relation, offset, limit)
            true_relations.map{|true_relation|
              puts "RELATION: #{true_relation.relation}, #{true_relation.principal_entity}, #{true_relation.secondary_entity} "
              puts "OFFSET: #{offset} "
              begin
                article = corpus.find_entity_article(true_relation.principal_entity) 
              rescue Exception => e
                puts "get error: #{e}"
                next
              end
              article_sentences = preprocessor.preprocess(article).map{|sentence|        
                sentence.principal_entity = true_relation.principal_entity
                sentence.secondary_entity = true_relation.secondary_entity
                sentence.relation = true_relation.relation
                sentence.offset = true_relation.offset
                sentence
              }
              relevant_sentences = Filtering.do_filter(article_sentences)      
              relevant_sentences.each{|sentence|        
                sentences_repository.save_sentence(sentence)
              }
              article_sentences
            }
            offset += (true_relations.size)        
          end
        }
        break
      rescue Exception => e
        puts "get error: #{e}"
        sleep(10)
        File.open('log/thread_exceptions.log', 'a'){|f|f.write("ERRO!!!!!\n")}
        File.open('log/thread_exceptions.log', 'a'){|f|f.write("  BEFORE OFFSET UPDATE" + relations.inspect+ "\n\n")}
        relations.each_key{|relation| relations[relation] = (sentences_repository.find_last_relation_offset(relation) + 1)}
        File.open('log/thread_exceptions.log', 'a'){|f|f.write("  AFTER OFFSET UPDATE" + relations.inspect+ "\n\n")}
        puts "UPDATED OFFSETS: #{relations.inspect}"
        puts "STARTING THREADS AGAIN"
        true_relations = [1]
        next
      end
    end
  end
  
  def self.populate_database
    require 'csv'
    i = 0
    CSV.foreach("d:/testesRelationExtraction/repository_production-examples-100.csv") do |row|
      sentence_text = row[1]
      source_page = row[2]
      target_page = row[3]
      property = row[4]
      class_source = row[5]
      class_target = row[6]
      puts sentence_text
      i+=1
      break if i == 10      
    end
    
    f2 = File.open("d:/testesRelationExtraction/repository_production-examples-100.csv", "w")
    f.each_line do |line|
      line_columns = line.split(",")  
    end
  end
  
  def self.train_classifier
    dataset_path = config.dataset_path
    classifier = config.classifier
    cross_validation_folds = config.cross_validation_folds
    classifier.start_trainning(dataset_path)      
    classifier.get_default_evaluator.cross_validate(cross_validation_folds) if cross_validation_folds
  end
  
  def self.generate_dataset
    sentence_repository = config.sentences_repository
    max_example_qtd = config.max_examples_quantity
    relations = config.relations_hash
    dataset_format = config.dataset_format
    
    data_matrix = []
    puts "RELATIONS SIZE: #{relations.size}"
    relations.each{|relation, offset|
      puts relation
      sentences = sentence_repository.find_sentence_by_relation(relation, max_example_qtd, 201)
#      puts "QTD: #{sentences.size}"      
       if(sentences.empty?)
         sentences = sentence_repository.find_sentence_by_relation(relation, max_example_qtd, 0)
       end
      filtered_sentences = Filtering.do_filter(sentences)
      puts "QTD Novamente: #{sentences.size}"
       if(filtered_sentences.size < 200)
         offset20_percent = filtered_sentences.size - (filtered_sentences.size * 0.2) - 1
#         filtered_sentences = filtered_sentences[(offset20_percent.to_i + 1)..filtered_sentences.size]
#         Generate training set
#         filtered_sentences = filtered_sentences[0..offset20_percent.to_i]
       end
      # puts sentences.inspect
      i = 0
      filtered_sentences.each{|sentence|          
        i+=1
        data_matrix << FeatureExtraction.extract(sentence)
        puts i
        # puts relation + ": "+ filtered_sentences.size.to_s + ": " + offset20_percent.to_s
      }
      
    }
    feature_matrix = []
    header = FeatureExtraction.get_attributes
    feature_matrix << header.map{|attr| attr.gsub('"', '\"')}
    feature_matrix += data_matrix
    puts "generating dataset"
    dataset_path = DatasetGeneration.generate(feature_matrix, dataset_format)
  end
  
  def self.do
    @@config = ConfigModule::Config.new    
    mine_examples if config.minning_enabled
    generate_dataset if config.dataset_generation_enabled
    train_classifier if config.trainning_enabled
	end
  
	def self.config
    @@config
  end
	
  def self.predict()
#    Prediction.predict("Morris Smith Miller (July 31, 1779 -- November 16, 1824) was a United States Representative from New York. Born in New York City, he graduated from Union College in Schenectady in 1798.")
#    Prediction.recognize_entities_from_google_dataset
    Prediction.generate_google_test_set
  end
#  predict
#	self.find_test_sentences
	self.do
#  compute_dep_list
end