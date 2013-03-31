require 'java'
require 'uuidtools'
require './model.rb'
require 'jdbc/mysql'
require './config.rb'

module Repositories
	module JavaSql
		include_package 'java.sql'
	end
	
  def self.create_db(db, connection_string, *db_config_params)
    case db
      when 'mysql'
        return MysqlRepository.new(connection_string)
        break;
      when 'sparql'
        return SparqlRepository.new(connection_string)
        break;
      when 'bioinfer'
        return BioInferRepository.new(connection_string)
        break;
      else
        raise('SGBD not supported!')
    end
  end
  
  class BioInferRepository
    attr_accessor :bioinfer_sentences_by_relation
    def initialize(corpus_path)
      require 'rexml/document'      
      corpus_file = File.new(corpus_path)
      doc = REXML::Document.new(corpus_file)      
      root = doc.root
      sentences = []
      doc.elements.each("bioinfer/sentences/sentence"){|stc|sentences<< stc}    
      @entities_hash = {}
      @sentences_by_relation = {}
      sentences.each{|bioinfer_stc|
        entities = []
        bioinfer_stc.elements.each("entity"){|bioinfer_entity|
          entity = Model::Entity.new(bioinfer_entity.attributes['id'])          
          entity.types << bioinfer_entity.attributes['type']
          @entities_hash[entity.id] = entity
        }
        
        formulas = []
        bioinfer_stc.elements.each("formulas/formula"){|f|formulas << f}        
        binary_relnodes = []      
        formulas.each{|f| f.elements.each("relnode"){|rel| get_binary_relnodes(rel, binary_relnodes)}}
        binary_relnodes.each{|relnode|
          relation_id = relnode.attributes['predicate']          
          entity_nodes = []
          relnode.elements.each("entitynode"){|entity_node| entity_nodes << entity_node}
          sentence = Model::Sentence.new()
          sentence.relation = relation_id
          sentence.text = bioinfer_stc.attributes['origText']
          sentence.principal_entity = @entities_hash[entity_nodes[0].attributes['entity']]
          sentence.secondary_entity = @entities_hash[entity_nodes[1].attributes['entity']]
          sentence.tokenizer = ConfigModule.config.tokenizer
          sentence.text_cleaner = ConfigModule.config.text_cleaner
          sentence.radical_extractor = ConfigModule.config.radical_extractor
          @sentences_by_relation[relation_id] ||= Array.new()
          @sentences_by_relation[relation_id] << sentence
        }
      }      
    end
    
    def get_binary_relnodes(relnode, relnodes)
      
      relnode.elements.each("relnode"){|r|
          relnodes = get_binary_relnodes(r, relnodes)          
      }
      entity_nodes = []
      relnode.elements.each("entitynode"){|en| 
        entity_nodes << en
      }
      
      relnodes << relnode if (!entity_nodes.empty? && entity_nodes.size == 2)
        
      relnodes
    end
    
    def find_all_classes(pattern=nil)
      all_types = []
      @entities_hash.each_value{|entity| all_types << entity.types}
      all_types.flatten.uniq
    end
    
    def find_words
      words = []
      @sentences_by_relation.each_value{|stc_array| words << stc_array.map{|stc| stc.text.split(" ")}}
      words.flatten.uniq.map{|w| w.downcase.gsub(/[^a-zA-Z0-9 \[\]\-]/, "")}
    end
    
    def find_sentence_by_relation(relation, limit = nil)
      limit ||= @sentences_by_relation[relation].size
      @sentences_by_relation[relation][0..limit-1]
		end
  end
  
	class MysqlRepository
		def initialize(connection_string)
			@connection_string = connection_string
			get_connection
		end
		
		def get_connection
			@conn ||= JavaSql::DriverManager.getConnection(@connection_string)      
			@conn
		end
		
    def execute_query(sql_query, parameter_values=nil)			
      puts sql_query
      
      if parameter_values
        # puts "PARAMETER: #{parameter_values[0]} #{parameter_values[0].class}"
        ps = @conn.prepareStatement(sql_query)
        for i in(0..parameter_values.size-1)
          ps.setString(i+1, parameter_values[i])
        end	        
        rs = ps.executeQuery()
      else        
        stmt = @conn.createStatement
        # puts "CHEGUEI AQUI"
        rs = stmt.executeQuery(sql_query)
      end      
			rs
		end
		
		def execute_update(sql_query, parameter_values)
      ps = @conn.prepareStatement(sql_query)
      for i in(0..parameter_values.size-1)
        ps.setString(i+1, parameter_values[i])
      end			
			rs = ps.executeUpdate()
			rs
		end
    
    def find_all_gov_nodes
      query = "select distinct gov from dependencies"
      rs = execute_query(query)
      gov_nodes = []
      while rs.next do
        gov_nodes << rs.getString(1)
      end
      gov_nodes
    end
    
    def find_all_shortest_paths
      conn = JavaSql::DriverManager.getConnection("jdbc:mysql://localhost:3306/sentence_db?user=root&password=db@dm348")
      path_query = "select path from sentence_paths where type = 'SHORTEST-PATH'"
      stmt = conn.createStatement
			rs = execute_query(path_query)
      path_list = []      
      while rs.next do
        path = rs.getString(1)
        path_list << path.split(",")
      end
      return path_list
    end
    
    def find_all_classes(pattern=nil)
      conn = JavaSql::DriverManager.getConnection("jdbc:mysql://localhost:3306/pt_sentences_db?user=root&password=db@dm348")
      
      stmt = conn.createStatement
			
      classes_query = "select distinct class from uri_classes"
      classes_query << " where class like '%#{pattern}%'" if pattern
													
			rs = execute_query(classes_query)
			dbpedia_ont_classes = []
			while rs.next do
				dbpedia_ont_classes << rs.getString(1)
			end
      dbpedia_ont_classes
    end
    
    def find_words
      words_query = "select distinct word from words"      
      rs = execute_query(words_query)
      words = []
			while rs.next do
				words << rs.getString(1)
			end
      words
    end
    
    def find_first_shortest_path(sentence)
      path_query = "select path from sentence_paths where stc_id = '#{sentence.id}' and type = 'SHORTEST-PATH'"
      rs = execute_query(path_query)
      path = nil
      if rs.next
        path = rs.getString(1)
      end
      return path.nil??nil:path.split(",")
    end
    
    def find_dependency_list(sentence)
      query = "select d.dep, d.gov, d.relation from dependencies d where d.stc_id = '#{sentence.id}'"
      rs = execute_query(query)
      dep_list = []
      while rs.next do
        dep_str = rs.getString(1)
        dep = NLP::Node.new(dep_str.split("-idx-")[0], dep_str.split("-idx-")[1].to_i)
        
        gov_str = rs.getString(2)        
        gov = NLP::Node.new(gov_str.split("-idx-")[0], gov_str.split("-idx-")[1].to_i)
        relation = rs.getString(3)        
        dep_list << NLP::Dependency.new(gov, dep, relation)
      end
      dep_list
    end
    
    def find_corref(sentence_id)
      sql = "select corref from correfs where stc_id = '#{sentence_id}'"
      corref = nil
      rs = execute_query(sql)
      while rs.next do
        corref = rs.getString(1)
      end
      corref
    end
    
    def find_all_sentences
      sql = "select * from sentences"      
      mount_sentence_list(execute_query(sql))
    end
    
    def save_attributes(attributes)
      sql = "insert into words values(?)"
      attributes.each{|attr| execute_update(sql, [attr])}
    end
    
    def save_path(path, sentence, type)
      path_string = path.join(",")
      stc_id = sentence.id
      sql_insert = "insert ignore into sentence_paths values(?,?,?) "
      execute_update(sql_insert, [path_string, stc_id, type])
    end
    
    def find_sentence(id)
			sql = "select * from sentences where id like '%#{id}%'"
			mount_sentence_list(execute_query(sql))
		end
		
		def find_sentence_by_text(text)
			sql = "select * from sentences where text like '%#{text}%'"
			mount_sentence_list(execute_query(sql))
		end
		
		def find_sentence_by_principal_entity(principal_entity)
			sql = "select * from sentences where source_page like '%#{principal_entity}%'"
			mount_sentence_list(execute_query(sql))
		end
		
		def find_sentenceby_secondary_entity(secondary_entity)
			sql = "select * from sentences where target_page like '%#{target_entity}%'"
			mount_sentence_list(execute_query(sql))
		end
		
		def find_sentence_by_relation(relation, limit = nil, offset = nil)
			sql = "select * from sentences s where s.property like '%#{relation}'
           and s.id in (select stc_id from sentence_paths)"      
			sql = sql << " limit #{limit}" if limit
      sql = sql << " offset #{offset}" if offset
      
      puts sql
			mount_sentence_list(execute_query(sql))
		end
    
    def find_sentence_by_relation_and_offset(relation, offset)      
			sql = "select * from sentences s where s.property like '%#{relation}' and offset > #{offset}
        and s.id in (select stc_id from sentence_paths)"      
      puts sql
			mount_sentence_list(execute_query(sql))
		end
    
    def find_last_relation_offset(relation)
      query = "select s.offset from sentences s where s.property like '%#{relation}' order by cast(offset as unsigned) desc"
      rs = execute_query(query)
      if rs.next
        return rs.getString(1).to_i
      else
        return 0
      end
    end
		
    def find_entity(id)
      entity = Model::Entity.new(id)
      entity.types = find_entity_types(id)
      entity
    end
    
    def find_entity_types(entity_id)
      sql = "select class from uri_classes where uri = ?"
			types = []
			rs = execute_query(sql, [entity_id])
			while rs.next do
				types << rs.getString(1)
			end
			types
    end
    
		def mount_sentence_list(result_set)
			sentence_list = []
			while result_set.next do
				sentence = Model::Sentence.new
				sentence.id = result_set.getString(1)
				sentence.text = result_set.getString(2)
        puts "id: #{sentence.id}"
        # puts "TEXT: #{sentence.text}"
				sentence.principal_entity = find_entity(result_set.getString(3))
				sentence.secondary_entity = find_entity(result_set.getString(4))
				sentence.relation = result_set.getString(5)
        sentence.tokenizer = ConfigModule.config.tokenizer
        sentence.text_cleaner = ConfigModule.config.text_cleaner
        sentence.radical_extractor = ConfigModule.config.radical_extractor
				sentence_list << sentence
			end
			sentence_list
		end
    
    def save_sentence(sentence)
      id = UUIDTools::UUID.random_create.to_s
      text = sentence.text
      property = sentence.relation
      pe = sentence.principal_entity
      se = sentence.secondary_entity      
      offset = sentence.offset      
      query = "insert into sentences values(?, ?, ?, ?, ?, ? )"
      execute_update(query, [id, text, pe, se, property, offset.to_s])
    end
    
    def insert_corref(corref, entity)
      query = "insert into correfs values(?, ?)"
      execute_update(query, [entity, corref])
    end
    
    def save_dependency_list(dependency_list, sentence)
      dependency_list.each{|typed_dependency|
        id = UUIDTools::UUID.random_create.to_s
        stc_id = sentence.id
        rel = typed_dependency.relation
        gov = typed_dependency.gov.to_s
        dep = typed_dependency.dep.to_s
        query = "insert into dependencies values(?, ?, ?, ?, ? )"
        execute_update(query, [id, stc_id, rel, gov, dep])
      }
    end
    
    def find_last_dep_list_offset(relation)
      sql = "select max(s.offset) from sentences s, dependencies d
              where s.id = d.stc_id and s.property like '%#{relation}'"
      puts "FINDING OFFSET"
      rs = execute_query(sql)
      if rs.next
        offset = rs.getInt(1).to_i
        puts "LAST OFFSET FOR #{relation}: #{offset}"
        return offset
      else
        return 0
      end
    end
	end
	
  class SparqlRepository
  
    def initialize(endpoint_url, *endpoint_config_params)
      require 'active_rdf'
      @endpoint_adapter = ConnectionPool.add_data_source(:type => :sparql,
      :url => endpoint_url,
      :engine => :virtuoso,
      :timeout => 10000000)
    end
    
    def execute_query(sparql_query)
      @endpoint_adapter.execute_sparql_query(sparql_query)
    end
    
    def find_true_relations(relation_id, *offset_limit)       
      true_relations = []
      initial_offset = offset_limit[0]
      offset = initial_offset
      initial_limit = offset_limit[1]
      limit = initial_limit
      result_set = [1]
      puts relation_id    
      puts "OFFSET: #{offset}"
      puts "LIMIT: #{limit}"
      sparql_query = "select ?subject, ?object where{?subject <#{relation_id}> ?object.}"     
      sparql_query << " OFFSET #{offset}" if offset
      sparql_query << " LIMIT #{limit}" if limit
      while (true) do
        begin
          result_set = @endpoint_adapter.execute_sparql_query(sparql_query)
          count = 0
          true_relations += result_set.map{|subject_object|               
            rel = Model::Relation.new(subject_object[0].uri.to_s, relation_id, subject_object[1].uri.to_s, offset + count)
            count += 1
            rel
          }
        break
        rescue Exception=>e
          puts("EXCEPTION FOUND: #{e.to_s} GOING SLEEP")
          sleep(5)
          puts("TRYING AGAIN")
          next
        end
      end
     puts "RELATIONS QTD: #{true_relations.size}"
     true_relations 
    end
  end
end