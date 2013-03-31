module ConfigModule
  def self.set_config(config)
    @@config = config
  end
  def self.config
    @@config
  end
  class Config
    attr_accessor :relations_hash, :tokenizer, :text_cleaner, :radical_extractor, :sentence_extractor, 
                  :preprocessor, :dataset_format, :dataset_folder, :dataset_name, :dataset_path, 
                  :uri_pattern, :parser, :corref_analyser, :max_examples_quantity, :uri_pattern, :sentences_repository,
                  :relations_repository, :corpus, :classifier, :classifier_folder, :classifier_settings,
                  :cross_validation_folds, :minning_enabled, :trainning_enabled, :dataset_generation_enabled
                  
                  
    def initialize
      profile = File.read('./config/profile.txt').strip
      config = YAML.load_file("./config/#{profile}.yml")
      initialize_modules(config)
      ConfigModule.set_config(self)
    end
    
    def load_nlp_module(settings)
      parser_class = settings['nlp']['parser']
      grammar_path = settings['nlp']['grammar']
      @parser = eval("NLP::#{parser_class}.new(grammar_path)")
    end
    
    def load_information_extraction_module(settings)
      corref_analyser_class = settings['information_extraction']['correference_analyser']
      corpus_class = settings['information_extraction']['corpus']['class']
      corpus_url = settings['information_extraction']['corpus']['url']
      lang = settings['information_extraction']['corpus']['lang']
      @corpus = eval("Corpus::#{corpus_class}.new(corpus_url, lang)")
      @corref_analyser = eval("InformationExtraction::#{corref_analyser_class}.new(@corpus)")
    end
    
    def load_db_settings(settings)    
      conn_string = settings['location']
      db = settings['db']
      Repositories.create_db(db, conn_string)
    end
    
    def load_preprocessing_module(settings)
      tkn_class = settings['preprocessing']['tokenizer']
      txt_cln_class = settings['preprocessing']['text_cleaner']
      rdc_ext_class = settings['preprocessing']['radical_extractor']
      stc_ext_class = settings['preprocessing']['sentence_extractor']
      @tokenizer = nil
      @text_cleaner = nil
      @radical_extractor = nil
      @sentence_extractor = nil    
      @tokenizer = eval("Preprocessing::#{tkn_class}.new()") if tkn_class
      @text_cleaner = eval("Preprocessing::#{txt_cln_class}.new()") if txt_cln_class
      @radical_extractor = eval("Preprocessing::#{rdc_ext_class}.new()") if rdc_ext_class
      @sentence_extractor = eval("Preprocessing::#{stc_ext_class}.new()") if stc_ext_class
      @preprocessor = Preprocessing::Preprocessor.new(@text_cleaner, @tokenizer, @sentence_extractor)
    end
    
    def load_filtering_settings(settings)
      settings['filters'].each{|filter_class| Filtering.add_filter(eval("Filtering::#{filter_class}.new"))}
    end
    
    def load_target_relations(settings)
      @relations_hash = {}
      settings['target_relations'].each{|relation|
        offset = 0 if relation.split(":").size < 2
        offset ||= relation.split(":")[1].to_i
        relation = relation.split(":")[0]
        relation_id = (@uri_pattern + relation)
        puts relation_id
        relation_id ||= "http://dbpedia.org/ontology/#{relation}"
        @relations_hash[relation_id] = offset
      }
    end
    
    def load_feature_extaction_module(settings)
      settings['feature_extractors'].each{|ext_class|
        extractor = eval("FeatureExtraction::#{ext_class}.new(@sentences_repository, @uri_pattern)")
        extractor.radical_extractor = @radical_extractor
        extractor.corref_analyser = @corref_analyser
        extractor.parser = @parser
        puts extractor.radical_extractor
        FeatureExtraction.add_extractor(extractor)
      }		
      @dataset_format = DatasetGeneration.create_formatter(settings['dataset_format'], @dataset_path)
    end
    
    def load_dataset_path(settings)
        @dataset_path = "#{settings['dataset_folder']}/#{settings['dataset_name']}.#{settings['dataset_format']}"    
    end
    
    def load_minning_config(settings)
      @uri_pattern = settings['uri_pattern']
      @uri_pattern ||= ""
      @max_examples_quantity = settings['max_examples_quantity']
      load_target_relations(settings)
      load_preprocessing_module(settings)
      load_filtering_settings(settings)    
      @sentences_repository = load_db_settings(settings['db_config'])
      @relations_repository = load_db_settings(settings['relations_db_config'])      
    end
    
    def load_trainning_config(settings)    
      load_dataset_path(settings)
      @classifier_settings = settings['classifier_settings']
      @classifier_folder = settings['classifier_folder']
      @classifier = eval("Classification::#{settings['classifier']}.new(#{@classifier_settings})")
      @cross_validation_folds = settings['cross_validation_folds']    
    end
    
    def load_dataset_generation_config(settings)    
      @uri_pattern = settings['uri_pattern']
      @uri_pattern ||= ""
      load_preprocessing_module(settings)
      load_filtering_settings(settings)
      @max_examples_quantity = settings['max_examples_quantity']
      @sentences_repository = load_db_settings(settings['db_config'])    
      load_dataset_path(settings)
      load_target_relations(settings)
      load_feature_extaction_module(settings)    
    end
    
    def initialize_modules(config)      
      load_nlp_module(config)
      load_information_extraction_module(config)
      @minning_enabled = config['minning']['enabled'] == 'yes'? true:false
      load_minning_config(config['minning']) if @minning_enabled
      
      @dataset_generation_enabled = config['dataset_generation']['enabled'] == 'yes'? true:false
      load_dataset_generation_config(config['dataset_generation']) if @dataset_generation_enabled
      
      @trainning_enabled = config['trainning']['enabled'] == 'yes'? true:false
      load_trainning_config(config['trainning']) if @trainning_enabled  
    end
    
  end
end