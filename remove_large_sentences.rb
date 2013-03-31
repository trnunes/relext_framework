require 'rubygems'
require 'active_rdf'
require 'java'
require 'jdbc/mysql'
	module JavaSql
		include_package 'java.sql'
	end
@connection_string = "jdbc:mysql://localhost:3306/sentence_db?user=root&password=db@dm348"
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
rs = execute_query("select distinct text, id from sentences")
subjects = []
count = 0
acc_size = 0
stc_list = []
while(rs.next)
  count += 1
  stc = []
  stc[0] = rs.getString(1)
  stc[1] = rs.getString(2)
  stc_list << stc
  acc_size += stc[0].split(" ").size
end
media = acc_size/count
bigger_size = 0
stc_big_size = ""
stc_list.each{|stc| 
  s = stc[0].split(" ").size
  if s > bigger_size && s <= (70)
    stc_big_size = stc
    bigger_size = s
  end
}

above_media = stc_list.select{|stc| stc[0].split(" ").size >= (70)}.size
puts "Total: #{stc_list.size}"
puts "QUANTIDADE ACIMA DA MÉDIA: #{above_media}"
puts stc_big_size
puts "MEDIA: #{media}"

