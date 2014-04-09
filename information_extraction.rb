require 'uri'
require 'java'
require './lib/secondstring-20120620.jar'
include_class 'com.wcohen.ss.JaroWinkler'
module InformationExtraction
  LOG = './log/information_extraction.log'
  File.open(LOG, 'w'){|f| f.write("")}
  
  def self.log(msg)
    File.open(LOG, 'a'){|f| f.write(msg << "\n")}
  end
  
  class WikipediaCorreferenceAnalyser
    def initialize(wikipedia_corpus)      
      @wikipedia_corpus = wikipedia_corpus
      @count = 0
    end
    
   def pre_analyse(sentence, repository=nil)      
     jaro_winkler = JaroWinkler.new 
     correference = nil
     title = sentence.principal_entity.label
     title ||= URI.unescape(sentence.principal_entity.id).scan(/http:\/\/.*\/(.*)/).first.first.split("_").map{|t| t.downcase}
     puts  "TITLE: #{title.inspect}"
     bold_names = sentence.text.gsub("'''''", "@").gsub("'''", "@").scan(/(@([^@]*)@)/)
#      puts '  '+bold_names.inspect
     if !bold_names.empty?
       first_name = bold_names[0][1].downcase.gsub("\"", "")
#       puts "FIRST NAME: #{first_name.inspect}"
#       puts "Score: " + jaro_winkler.score(first_name, title).to_s
       if (jaro_winkler.score(first_name, title) >= 0.8)
         @count+=1
         InformationExtraction.log("CORREFERENCE #{@count}: #{first_name.inspect}")
         correference = first_name
         # puts "CORREFERENCE: #{correference}"
         unless repository.nil?
           repository.insert_corref(correference, sentence.id)
         end   
       end
     else
       first_name = []
       title_tokens = title.split(" ").map{|w| w.downcase.strip.gsub(/(?=\S)(\d|\W)/,"")}
       snippet = sentence.principal_entity.snippet
       tokens = snippet.split(" ").map{|w| w.downcase.strip.gsub(/(?=\S)(\d|\W)/,"")}       
       
       correference = first_name.join(" ")
       if(correference.empty?)
         i = 0
         begin
           
           possible_ref_tokens = tokens[i..i+(title_tokens.size-1)]
#           puts "Title TOKENS #{title_tokens.inspect}"
           ref_tokens = possible_ref_tokens.select{|token| 
             title_tokens.include?(token.downcase)         
           } 
#           puts "POSSIBLE REF TOKENS #{possible_ref_tokens.inspect}"
#           puts "REF TOKENS #{ref_tokens.inspect}"
           index_last = 1000
           ref_tokens.each{|token|
            
             token_index = possible_ref_tokens.index(token)
             diff = token_index - index_last
             if(diff > 1)
               diff.times do |i|
                 first_name << possible_ref_tokens[(index_last+1) + i]
               end              
             else
               first_name << token
             end
             index_last = token_index
             
            }
#            puts "FIRST NAME: #{first_name.inspect}"
            if !first_name.empty?
              correference = first_name.join(" ")
              break 
            end
            i+= title_tokens.size
#            puts "I: #{i}"
         end while i < tokens.size
      
       end
    end
    
     correference
    end
    
    def get_most_frequent_pronoun(text, entity_label = nil)
      pronouns_list = [ "theirs","them","themselves","these","they","this","those", "it","its",
      "itself","he","him", "his", "she", "her","hers","herself","himself"]
      pronoun_freq = 0
      most_frequent_pronoun = nil
      pronouns_list.each{|pronoun|        
        occurrence_count = text.downcase.scan(/ #{pronoun} /).size
        if(entity_label)
          text.split(",").each{|piece|
          
            if(piece.split(" ").select{|token|token.strip.downcase == pronoun}.size > 0 && piece.include?(entity_label))
              if(most_frequent_pronoun != "he" && most_frequent_pronoun != "she")
                puts "MOST FREQUENT PRONOUN: #{most_frequent_pronoun} adf"
                puts most_frequent_pronoun != "he"
                puts "PRONOUN: #{pronoun}"
                most_frequent_pronoun = pronoun
              end
            end
          }
        else
          if occurrence_count > pronoun_freq
            puts "OCCURRENCE: #{occurrence_count}"
            most_frequent_pronoun = pronoun
            pronoun_freq = occurrence_count
          end
        end
      }
      
      most_frequent_pronoun
    end
    
    def analyse(sentence, subject_list,repository=nil)
      text_cleaner = sentence.text_cleaner
      title = URI.unescape(sentence.principal_entity.id).scan(/http:\/\/.*\/(.*)/).first.first.split("_").map{|t| t.downcase}
      stc_text = sentence.text.dup.gsub("'''", ' ').gsub("''", ' ')
      clean_text = stc_text.downcase
      
      intersec = clean_text.split(" ") & title
      text = @wikipedia_corpus.find_entity_article(sentence.principal_entity.id) 
      
      # if intersec.size > 1
        # @count +=1
        # InformationExtraction.log("BEGIN CORREFERENCE ANALYSIS FOR TITLE: #{title.inspect}")
        # InformationExtraction.log(" TEXT: #{clean_text}")  
        # InformationExtraction.log(" INTERSECTION: #{intersec.join(" ")}")
        # correference = stc_text.downcase.scan(/#{intersec.join(" ")}/)
        # InformationExtraction.log(" CORREFERENCE #{@count}: #{correference.inspect}")
      # end

      most_frequent_pronoun = get_most_frequent_pronoun(text)  
      correfence = nil
      subject_list.each{|subj_part|
        subj_label = subj_part.label
        # puts "ANALYSING: #{subj_label}"
        if title.include?(subj_label.downcase.strip) || subj_label.downcase.strip == most_frequent_pronoun.to_s.downcase    
          correfence = subj_part
          break
        end
      }
      # puts " END CORREFERENCE ANALYSIS FOR TITLE: #{correfence}"    
      
      unless repository.nil? || correfence.nil?
        repository.insert_corref(correfence.label, sentence.id)
      end
      correfence
    end    
  end 
  
  class WikipediaSecondaryEntityRecognizer
    
    def recognize(sentence)
      sentence.secondary_entity.id.scan(/http:\/\/.*\/(.*)/).first.first.gsub("_", " ")
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
    end 
  end
  
  class MarkedEntityRecognizer
        
    def recognize(sentence)
      sentence.secondary_entity.id.scan(/http:\/\/.*\/(.*)/).first.first.gsub("_", " ")
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
    end 
  end
end