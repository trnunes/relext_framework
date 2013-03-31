module BOWBuilder
  class WikipediaBOW  
    def get_words(repository)
      words = []
      sentences = repository.find_all_sentences
      sentences.each{|stc|
        rad_ext = stc.radical_extractor
 
        text = stc.text.dup        
        sentence_markups = text.to_s.scan(/(\[\[([^\]]*)\]\])/)      
        sentence_markups.each{|markup|        
          text.gsub!(markup[0].to_s, markup[1].to_s.split("|")[0].to_s)
          
        }
        stc.text = text
        stc.clean_text
        tokens = stc.tokenize        
        words += tokens.map{|t|
          if t =~ /\d/
            "num"
          else
            t.downcase.strip
          end
        }
      }
      words.uniq!
      words.compact!
      puts words.inspect
      # File.open('log/ptswords.log', 'w'){|f|f}
      # words.each{|w|File.open('log/ptswords.log', 'a'){|f|f.write(w.strip + "\n")}}
      repository.save_attributes(words)
      puts words.size
    end
    
  end
  
end