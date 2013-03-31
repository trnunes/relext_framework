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
@connection_string = "jdbc:mysql://localhost:3306/pt_sentences_db?user=root&password=db@dm348"
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
puts "FINDING ALL SUBJECTS"
rs = execute_query("select distinct source_page from sentences")
subjects = []
while(rs.next)
  subjects << rs.getString(1)
end

rs = execute_query("select distinct target_page from sentences")
while(rs.next)
  subjects << rs.getString(1)
end
puts "SUBJECTS SIZE: #{subjects.size}"
puts "FINDING ALL TYPED SUBJECTS"
rs = execute_query("select distinct u.uri from uri_classes u")
typed_subjects = []
while(rs.next)
  typed_subjects << rs.getString(1)
end

puts "TYPED SUBJECTS SIZE: #{typed_subjects.size}"

typed_subjects.uniq!
puts "TYPED SUBJECTS uniq SIZE: #{typed_subjects.size}"
subjects = subjects.uniq.sort{|s1,s2| s1<=>s2}
puts "SUBJECTS UNIQ SIZE: " + subjects.size.to_s
subjects = subjects - typed_subjects
puts "SUBJECTS - TYPED SUBJECTS: #{subjects.size}"
@endpoint_adapter = ConnectionPool.add_data_source(:type => :sparql,
:url => "http://pt.dbpedia.org/sparql",
:engine => :virtuoso,
:timeout => 10000000)
i = 0
subjects.threach(10){|s|  
  puts "FINDING CLASS FOR: #{s}"
  while(true) do
    begin
      res = @endpoint_adapter.execute_sparql_query("select ?c where{ <#{s}> a ?c}").flatten  
      break
    rescue Exception => e
      puts "PROBLEM: #{e}"
      sleep(5)
      puts "TRYING AGAIN"
      next
    end
  end
  if res.empty?
    puts "NO CLASS"
    execute_update("insert into uri_classes values(?,?,?)", [s,"THING", i])
  else
    res.each{|klass| 
      puts " CLASS: #{klass.uri.to_s}"
      execute_update("insert into uri_classes values(?,?,?)", [s,klass.uri.to_s, i])
    }
  end
  i+=1
}