module Corpus
  class WikipediaCorpus
    def initialize(url, lang)
      @url = url
      @lang = lang
    end
    
    def find_entity_article(entity_id)
      require 'net/http'
      
      url_match = entity_id.scan(/http:\/\/.*\/(.*)/)
      if(url_match.empty?)
        wikipedia_page_name = entity_id
      else
        wikipedia_page_name = url_match.first.first
      end    
      
#      article_url = "#{@url}/#{CGI::escape(wikipedia_page_name)}?action=raw"
#      puts article_url
#      
#      if @url.include?("localhost")
#        get_html_content(article_url, wikipedia_page_name)
#      else  
        import_raw_wikipedia_page(wikipedia_page_name)
#      end
    end
    
    def get_html_content(requested_url, wikipedia_page_name)
      url = URI.parse(requested_url)
      
      full_path = (url.query.nil?) ? url.path : "#{url.path}?#{url.query}"
      the_request = Net::HTTP::Get.new(full_path)
      the_response = Net::HTTP.start(url.host, url.port) { |http|
        http.request(the_request)
      }

      return import_raw_wikipedia_page(wikipedia_page_name) if the_response.code != "200"
        
      return the_response.body
    end 
    
    def import_raw_wikipedia_page(wikipedia_page_name)
    require 'net/http'
    puts "VAMO PRA NET!!!!"
    Net::HTTP.start("#{@lang}.wikipedia.org") { |http|
      resp = http.get("/wiki/#{CGI::escape(wikipedia_page_name)}?action=raw", 'User_Agent' => 'swwiki')
      puts "Terminei Wikipedia"
      return resp.body.to_s
    }
    raise "Page not found"
  end  
  end
  

end