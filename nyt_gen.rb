require 'rubygems'
require 'json'
require 'java'
require 'uuidtools'
require 'jruby_threach'

require 'jdbc/mysql'
require 'active_rdf'
	module JavaSql
		include_package 'java.sql'
	end
@connection_string = "jdbc:mysql://localhost:3306/nyt_db?user=root&password=db@dm348"
def get_connection
  @conn ||= JavaSql::DriverManager.getConnection(@connection_string)
  @conn
end
get_connection
def execute_query(sql_query)
  stmt = @conn.createStatement
  rs = stmt.executeQuery(sql_query)
  rs
end

def execute_update(sql_query, parameter_values)
  ps = @conn.prepareStatement(sql_query)
  for i in(0..parameter_values.size-1)
    if parameter_values[i].class == Fixnum
      ps.setInt(i+1, parameter_values[i])
    else
      ps.setString(i+1, parameter_values[i])
    end
  end			
  rs = ps.executeUpdate()
  rs
end
execute_update("insert into uri_classes values (?,?,?)", ["arg1","http://dbpedia.org/ontology/Organisation",10])
execute_update("insert into uri_classes values (?,?,?)", ["arg2","http://dbpedia.org/ontology/Person",10])
puts "FINDING ALL Sentences"
lines = File.readlines("./datasets/DataSet-IJCNLP2011/data_sets/New_York_Times.txt")
begin_stc = false
sentence_list = []
sentence = ""
id = ""
flag = false
sentence_lines = lines.each{|line|  
  begin_stc = true   if line.include?("NYT")
  begin_stc = false   if line == ("\n") 
  if begin_stc
    if line.include?("NYT")
      sentence = ""
      id = line.split(" ")[0]
      flag = false
    else
      flag = true if line.include?("B-R")
      token = line.split(" ")[1]
      sentence << token + " "      
    end
  else
    execute_update("insert into sentences values (?,?,?,?,?,?)", [id, sentence, "arg1","arg2", "?", 10]) if flag
    sentence_list << sentence
  end
}
