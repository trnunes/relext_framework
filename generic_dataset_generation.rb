module GenericDatasetGeneration
    
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
    require 'set'
    attr_accessor :feature_set, :instances, :class_feature, :klasses_set
    
    def initialize(class_feature, dataset_path=nil)
        @dataset_path = dataset_path
        @feature_set = Set.new
        @class_feature = class_feature
        @klasses_set = Set.new
        @instances = []
    end

    def add_instance(instance_feature_list)
        
        instance_feature_list[0..(instance_feature_list.size - 2)].each{|feature| @feature_set.add(feature)}
        @instances.push(instance_feature_list);
        @klasses_set.add(instance_feature_list.last)
        
    end
    
    def mount_header        
        header = "@RELATION re\n"
        count = 0
        puts @feature_set
        @feature_set.each{|attribute|
            arff_attribute = "@ATTRIBUTE \"#{attribute}\" NUMERIC\n"
            header << arff_attribute
        }
        header << "@ATTRIBUTE \"#{@class_feature}\" {" + @klasses_set.map{|klass| "'" + klass + "'"}.join(",") + "}\n"
        header
    end
    
    def generate
        @feature_set = @feature_set.sort
        output_file_path = @dataset_path
        output_file_path ||= "./trainning_data/dataset.csv"
        
        File.open(output_file_path, 'w')
        
        header = mount_header
        header << "\n@DATA\n"
        File.open(output_file_path, 'a'){|f| f.write(header)}
        @instances.each{|instance|
            
            line = "{"
            klass = instance.delete(instance.last)

            instance = instance.sort
            instance << klass
            puts instance.inspect
            instance.each{|feature|
                index = @feature_set.find_index(feature)
                if index != nil
                    line << ("#{index} " + "1" + ",")
                end
                if(feature == instance.last)
                    line << ("#{@feature_set.size} " + feature + ",")
                end
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