
new_dataset = ""
lines = File.readlines("trainning_data/trainning_500_1.arff");puts
attributes = lines[1..54159];puts
lexical = ARGV[0].to_i || 1
shortest_path = ARGV[1].to_i|| 1
types = ARGV[2].to_i|| 1
file_name = ARGV[3] || "new_dataset"
file_name << ".arff" if(!file_name.include?(".arff"))
instances = lines[54162..lines.size];puts
instances.each{|instance_line|
  
  features = instance_line.gsub(/[{}]|\n/, "").split(",")
  features_to_delete = []
  features.each{|feature|    
    feature_number = feature.split(" ").first.to_i
    
     
    if(lexical == 0 && feature_number < 28202)        
      features_to_delete << feature + ","       
    end
    if(shortest_path == 0 && feature_number.between?(28202, 53673))        
      features_to_delete << feature + ","        
    end
    if(types == 0 && feature_number.between?(53674,54157))        
      features_to_delete << feature + ","        
    end
  }  
  features_to_delete.each{|feature| instance_line.sub!(feature, "")}
  new_dataset << instance_line
}; puts
header = lines[0..54161].join
File.open("trainning_data/#{file_name}", 'w'){|f|f.write(header << new_dataset)}; puts

#precision = ARGV[0].to_f
#recall = ARGV[1].to_f
#f = 2*((precision * recall)/(precision+recall))
#puts f