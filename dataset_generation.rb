module DatasetGeneration
	def self.generate(feature_matrix, format, types=nil)
		format.save(feature_matrix, types)
	end
	
  def self.create_formatter(format, dataset_path)
    case format
      when 'csv' 
        return CSVFormat.new(dataset_path)
        break;
      when 'arff' 
        return ARFFormat.new(dataset_path)
        break;
      else
        raise('Format not supported!')
    end
    
  end
  
	class ARFFormat
    def initialize(dataset_path=nil)
      @dataset_path = dataset_path
    end
    
    def mount_header(first_line, types)
      header = "@RELATION re\n"
      count = 0
      first_line.each{|attribute|
        count += 1
        type = 'NUMERIC'
        if count == first_line.size
          type = "{#{types.inspect.gsub(/[\[\]\"]/, "")}}"
        end
        arff_attribute = "@ATTRIBUTE \"#{attribute}\" #{type}\n"
        header << arff_attribute
      }
      header      
    end
    
		def save(matrix, types=nil)
      output_file_path = @dataset_path
			output_file_path ||= "./trainning_data/dataset.csv"
			File.open(output_file_path, 'w')			
			i = 0
      if(!types)
        types = matrix.map{|row| row[row.size - 1]}.uniq      
      end
      
      header = mount_header(matrix[0], types[1..types.size-1])
      header << "\n@DATA\n"
      File.open(output_file_path, 'a'){|f| f.write(header)}
			matrix.each{|row|
				i += 1
        if i == 1
          next
        end
        row_count = 0
				line = ""
        puts "ROW SIZE: #{row.size}" 
        line << "{"
				row.each{|element|
          
          if element != 0
            line << ("#{row_count} " +element.to_s + ",")
          end
          row_count += 1
				}				
				line[line.size-1] = "}"	
				line << "\n"
				File.open(output_file_path, 'a'){|f| f.write(line)}
			}
			output_file_path      
		end
	end
	
	class CSVFormat
    def initialize(dataset_path=nil)
      @dataset_path = dataset_path
    end
		def save(matrix)
      output_file_path = @dataset_path
			output_file_path ||= "./trainning_data/dataset.csv"
			File.open(output_file_path, 'w')
			dataset = ""
			i = 0			
			matrix.each{|row|
				i += 1
				dataset = ""
				row.each{|element|
					element = "'#{element}'" if(i==1)					
					dataset << (element.to_s + ",")					
				}				
				dataset[dataset.size-1] = ""	
				dataset << "\n"
				File.open(output_file_path, 'a'){|f| f.write(dataset)}
			}
			output_file_path
		end
	end
	
	class DatabaseFormat
		def save(matrix)
		end
	end
	
end