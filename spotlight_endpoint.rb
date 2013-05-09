require './model.rb'
module SpotlightEndpoint
  @@response_file_path = "recognized_entites.xml"
  @@dbpedia_spotlight_url = "http://spotlight.dbpedia.org/rest/annotate"
  
  def self.do_http_request(text)
    require 'net/http'
    url_string = "#{@@dbpedia_spotlight_url}?text=#{text}&confidence=0.2&support=20"
    url = URI.parse(URI.encode(url_string))    
    response = Net::HTTP.get_response(url)
    File.open(@@response_file_path, "w"){|f|f.write(response.body.to_s)}    
  end
  
  def self.parse_response
    require 'rexml/document'      
    response_xml_file = File.new(@@response_file_path)
    doc = REXML::Document.new(response_xml_file)    
    recognized_entities = []    
    doc.elements.each("Annotation/Resources/Resource"){|element|
      entity_uri = element.attributes["URI"]
      
      types = element.attributes["types"].split(",").select{|type|
        type.include?("DBpedia") && (type.include?("Person") || type.include?("Place"))
      }.map{|type| type.gsub("DBpedia:", "http://dbpedia.org/ontology/")}
      puts types
      surface_form = element.attributes["surfaceForm"]
      if(!types.empty?)
        recognized_entity = Model::Entity.new(entity_uri, surface_form, types, surface_form)        
        recognized_entities << recognized_entity        
      end
    }
    recognized_entities[0..1]
  end
  
  def self.recognize_entities_from_text(text)
    do_http_request(text)
    parse_response
  end
# puts recognize_entities_from_text("Barack Obama and his wife Michele Obama will meet the dictator of North Korea").map{|e|e.types}.inspect
end