require 'uri'
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
      correference = nil
      
      title = URI.unescape(sentence.principal_entity.id).scan(/http:\/\/.*\/(.*)/).first.first.split("_").map{|t| t.downcase}
      # puts  "TITLE: #{title.inspect}"
      bold_names = sentence.text.gsub("'''''", "@").gsub("'''", "@").scan(/(@([^@]*)@)/)
      # puts '  '+bold_names.inspect
      if !bold_names.empty?
        first_name = bold_names[0][1].downcase.gsub("\"", "").split(" ")
        # puts "FIRST NAME: #{first_name.inspect}"
        if (first_name - title).empty?
          @count+=1
          InformationExtraction.log("CORREFERENCE #{@count}: #{first_name.inspect}")
          correference = first_name.join(" ")
          # puts "CORREFERENCE: #{correference}"
           unless repository.nil?
            repository.insert_corref(correference, sentence.id)
          end
        end
      end
      correference
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
      pronouns_list = [ "theirs","them","themselves","these","they","this","those", "it","its",
      "itself","he","him", "his", "she", "her","hers","herself","himself"]
      pronoun_freq = 0
      most_frequent_pronoun = nil
      pronouns_list.each{|pronoun|        
        occurrence_count = text.downcase.scan(/ #{pronoun} /).size       
        if occurrence_count > pronoun_freq
          most_frequent_pronoun = pronoun
          pronoun_freq = occurrence_count
        end
      }      
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
end