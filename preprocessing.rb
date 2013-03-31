require 'stemmer'
module Preprocessing
	class Preprocessor
		attr_accessor :text_cleaner, :tokenizer, :sentence_extractor
		def initialize(text_cleaner, tokenizer, sentence_extractor)
      File.open("./log/structure_remotion.log", 'w'){|w| w}
			@text_cleaner = text_cleaner
			@tokenizer = tokenizer
			@sentence_extractor = sentence_extractor
		end
		
		def preprocess(article)            
      article = @text_cleaner.clean(article)
      
      sentence_list = @sentence_extractor.brake_in_sentences(article).map{|sentence_text|
        sentence = Model::Sentence.new()
        sentence.text = sentence_text
        sentence.tokenizer = tokenizer
        sentence.tokenize
        sentence
      }      
      
      sentence_list      
		end		
	end
	
	class DefaultTextCleaner
		def clean(text)
      # File.open("./log/structure_remotion.log", 'a'){|w| w.write("ORIGINAL: #{text}\n\n")}
			regex_list = get_regex_list			
			delimiters = get_delimiters      
			text = remove_structures(delimiters, text) if !delimiters.empty?
      regex_list.each{|regexp| text.gsub!(regexp, " ")}
      # File.open("./log/structure_remotion.log", 'a'){|w| w.write("TEXT: #{text}\n\n")}
      stripped_text = text.strip
      # File.open("./log/structure_remotion.log", 'a'){|w| w.write("CLEANED: #{stripped_text}\n\n")}
      stripped_text
		end
		
		def get_regex_list 
			[/\<ref\>/, /\<\/ref\>/, 
      /\<center\>/, /\<\/center\>/, /\{\{citar/,
      /\\n/, /[\/\.\,\+\*\=\:\;\_\'\"\\\(\)\[\]\?\<\>\|\#\$\%\&\!]/]
		end
		
		def get_delimiters
			[]
		end    
		
		def remove_structures(delimiters, text)
      delimiters_count = 0
      while delimiters_count < delimiters.size do
        begin_markup = delimiters[delimiters_count][0]
        end_markup = delimiters[delimiters_count][1]
        markup_begin_condition = ""
        for markup_index in (0..begin_markup.size-1)
          markup_part = begin_markup[markup_index]
          markup_begin_condition << "text[i+#{markup_index}].chr == #{markup_part}.chr&&"
        end
        markup_begin_condition[markup_begin_condition.size - 1] = ""
        markup_begin_condition[markup_begin_condition.size - 1] = ""
        markup_end_condition = ""
        for markup_index in (0..end_markup.size-1)
          markup_part = end_markup[markup_index]
          markup_end_condition << "text[i+#{markup_index}].chr == #{markup_part}.chr&&"
        end

        markup_end_condition[markup_end_condition.size - 1] = ""        
        markup_end_condition[markup_end_condition.size - 1] = ""

        text_copy = text.dup
        template = ""
        stack = []
        max_markup_size = [begin_markup.size, end_markup.size].max
        iteration = 0
        i = 0
        while (i < text.size) do  
          if(eval(markup_begin_condition))    
            stack.push("template_begin_found")
            iteration = i
          end
          template << text[i].chr if !stack.empty?        
          
          if(eval(markup_end_condition) && iteration != i)
            iteration = 0
            stack.pop
            for c in(1..max_markup_size-1)
                template << text[i+c].chr                
            end
            if stack.empty?
              text_copy.gsub!(template, "")
              template = ""              
            end
            i += max_markup_size
         
          else
            i+=1
          end
        end
        text = text_copy        
        delimiters_count +=1
      end
      text
		end		
	end
  
  class WikipediaTextCleaner < DefaultTextCleaner
  
    def get_regex_list
      #remove the wiki headers, the wiki lists (; and * markups)
			[/\=.*\=/, /;.*/, /\*.*/,
      /\<\/ref\>/, /\<\/ref\>/, 
      /\<center\>/, /\<\/center\>/,
      /\[\[Category:.*\]\]/]
		end
    
    def get_delimiters
      #delimiters for wikipedia templates and wikipedia tables respectively
      [["{{", "}}"], ["{|", "|}"]]
    end
  end
	
	class DefaultTokenizer
		def tokenize(sentence)
			sentence.text.split(" ").map{|w| w.downcase.strip}			
		end
	end
	
	class OpenNLPTokenizer < DefaultTokenizer
		def tokenize(sentence)			
		end
	end
	
	
	
	class SentenceExtractor
		def brake_in_sentences(article)
      article.split(".")
		end
	end
  
  class OpenNLPSentenceExtractor < SentenceExtractor
  
    def initialize
      require 'java'
      require 'lib/opennlp/opennlp-tools-1.5.0.jar'
      require 'lib/opennlp/lib/maxent-3.0.0.jar'
      require 'lib/opennlp/lib/jwnl-1.3.3.jar'
      
      java_import Java::java.io.FileInputStream
      java_import Java::opennlp.tools.sentdetect.SentenceModel
      java_import Java::opennlp.tools.sentdetect.SentenceDetectorME      
      modelIn = FileInputStream.new("./lib/opennlp/models/en-sent.bin")
      model = SentenceModel.new(modelIn)
      @sentenceDetector = SentenceDetectorME.new(model)
    end
    
		def brake_in_sentences(article)
      @sentenceDetector.sentDetect(article).map{|sc|sc}
		end
    
	end
	
	class DefaultRadicalExtractor
		def extract_radical(word)
			word.stem
		end
	end
  
  class PortugueseRadicalExtractor < DefaultRadicalExtractor
  
    def initialize
      require 'java'
      require 'lib/PTStemmer-2.0-Java/PTStemmer_v2.jar'
      java_import Java::ptstemmer.exceptions.PTStemmerException
      java_import Java::ptstemmer.Stemmer
      @stemmer = Stemmer.StemmerFactory(Stemmer::StemmerType::ORENGO)    
      @stemmer.enableCaching(1000)
      @stemmer.ignore("a","e")
    end
    
    def extract_radical(word)
      @stemmer.getWordStem(word)
    end
    
  end
  
end