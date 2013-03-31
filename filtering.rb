module Filtering

	def self.add_filter(filter)
		if @head_filter
			@head_filter.next=filter if @head_filter != filter
		else
			@head_filter = filter
		end
	end
	
	def self.do_filter(sentence_list)
		return sentence_list if !@head_filter
		return @head_filter.do_filter(sentence_list)		
	end
	
	class SentenceFilter
		attr_accessor :next		
		def do_filter(sentence_list)      
		end
	end
	
	class WikiLinkFilter < SentenceFilter
		
		def do_filter(sentence_list)
      filtered_sentence_list = sentence_list.select{|stc| 
        label ||= stc.secondary_entity.scan(/http:\/\/.*\/(.*)/).first.first.gsub("_", " ")
        sentence_markups = stc.text.to_s.scan(/(\[\[([^\]]*)\]\])/)
        
        link_to_target = sentence_markups.select{|markup|  
          markup[1].split("|")[0] == label
        }
        
        stc if !link_to_target.empty?
      }
      [filtered_sentence_list[0]].compact
		end
	end  
end