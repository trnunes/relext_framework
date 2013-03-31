require 'graph.rb'
module NLP
  class Node
    attr_accessor :label, :index, :children, :parent
    def initialize(label, index)
      @label = label
      @index = index
      @children = []     
    end
    def to_s
      label + "-idx-" + index.to_s
    end
  end
  
  class Dependency
    attr_accessor :gov, :dep, :relation
    def initialize(gov, dep, rel)
      @gov = gov
      @dep = dep
      @relation = rel
    end
    def to_s
      relation + "(" + gov.to_s + "," + dep.to_s + ")"
    end
  end
  class DepPatternDependencyParser  
    def initialize(grammar)
    end
    
    def compute_dependency_list(sentence)
      text = sentence.clean_text.strip
      text << "." if text[text.size - 1].chr != "."
      File.open('input.txt', 'w'){|f| f.write(text << "\n")}
      parse_string = %x[./lib/DepPattern-2.1/dp.sh -a treetagger pt input.txt]
      # puts "SENTENCE: " + text
      lines = parse_string.split("\n")
      lines[0] = nil
      lines.compact!
      dep = gov = relation = ""
      dep_list = lines.map{|dep_string| 
        dep_array = dep_string.gsub(/[\(\)]/, "").split(';')        
        if (dep_array[0] != nil && dep_array[1] != nil && dep_array[2] != nil)
          relation = dep_array[0]
          gov = dep_array[1]
          dep = dep_array[2]
          # puts "------------------------------X--------------------------------------"
          # puts "RELATION: " + relation
          # puts "GOV: " + gov
          # puts "DEP: " + dep
          gov = NLP::Node.new(gov.split("_")[0], gov.split("_")[2].to_i)
          dep = NLP::Node.new(dep.split("_")[0], dep.split("_")[2].to_i)        
          NLP::Dependency.new(gov,dep,relation)
        end
      }.compact
      dep_list
    end    
  end
  
  class StanfordDependencyParser
    def initialize(grammar)
      require 'java'
      require 'lib/stanford-parser-2012-03-09/stanford-parser.jar'
      require 'pqueue'
      java_import Java::edu.stanford.nlp.parser.lexparser.LexicalizedParser
      java_import Java::edu.stanford.nlp.trees.PennTreebankLanguagePack
      java_import Java::edu.stanford.nlp.trees.GrammaticalStructure
      java_import Java::java.util.Arrays
      java_import Java::java.io.StringReader      
      @parser = LexicalizedParser.getParserFromSerializedFile(grammar)
      @treebank = PennTreebankLanguagePack.new      
    end
    
    def compute_dependency_list(sentence)
      text = sentence.text.dup
      # puts "  BEGIN TOKENIZING"
      tokenizer = @treebank.getTokenizerFactory().getTokenizer(StringReader.new(text))
      wordlist = tokenizer.tokenize
      # puts "  END TOKENIZING: #{wordlist}"
      # puts "  BEGIN apply PARSING"
      parse = @parser.apply(wordlist)
      # puts "  END APPLY PARSING"
      # puts "  BEGIN CREATING GRAMATICAL STRUCTURE FACTORY"
			gsf = @treebank.grammaticalStructureFactory
      # puts "  END CREATING GRAMATICAL STRUCTURE FACTORY"
      # puts "  BEGIN CREATING GRAMATICAL STRUCTURE"
      grammaticalStructure = gsf.newGrammaticalStructure(parse)
      # puts "  END CREATING GRAMATICAL STRUCTURE"
      # puts "  BEGIN GETTING DEPENDENCY GRAPH"
      tdl = grammaticalStructure.allTypedDependencies()
      tdl.map{|td| 
        gov = Node.new(td.gov.label.to_s.split("-")[0], td.gov.index)
        dep = Node.new(td.dep.label.to_s.split("-")[0], td.dep.index)        
        Dependency.new(gov,dep,td.reln.to_s)      
      }      
    end    
  end
  
  def self.find_subjects(dependency_list)
    dependency_list.select{|td| td.relation.to_s.include?("subj")}.map{|td|td.dep}
  end
  
  def self.compute_shortest_path(dependency_list, source_node, target_node, shortest_path_strategy)
    direction_hash = {}    
    graph = Graph.undirected_graph_representation(dependency_list)
    nodes_by_index = graph[2]
    previous = shortest_path_strategy.compute_shortest_path(target_node.index, graph[0], graph[1], nodes_by_index.keys.max + 1)[1]
    path = [source_node]
    actual_index = source_node.index
    direction_hash[source_node] = ''
    while actual_index != target_node.index do
      predecessor_index = previous[actual_index]
      if predecessor_index.nil?
        FeatureExtraction.log("DISCONTINUED PATH")
        break
      end
      predecessor = nodes_by_index[predecessor_index]
      actual = nodes_by_index[actual_index]
      direction = ''
      if actual.children.include?(predecessor)
        direction_hash[predecessor] = "->"        
      else
        direction_hash[predecessor] = "<-"        
      end            
      path  << predecessor
      actual_index = predecessor_index 
    end
    [path, direction_hash]
  end  
end