module Classification
	class Evaluator
    def initialize(classifier, data)
      @classifier = classifier
      @data = data
    end
    
    def cross_validate(num_folds)    
    end
  end
  
  class WekaEvaluator < Evaluator
    def initialize(classifier, data)
      super(classifier, data)
      @native_classifier = @classifier.native_classifier
    end
    
    def cross_validate(num_folds)
      include_class 'weka.classifiers.Evaluation'
      include_class 'java.util.Random'
      puts "Importei"
      evaluator = Evaluation.new(@data)
      puts "INSTANCIEI AVALIADOR"
      evaluator.crossValidateModel(@native_classifier, @data, num_folds, Random.new(1))
      puts "AVALIEI"
      puts evaluator.toSummaryString.to_s
      puts evaluator.toClassDetailsString.to_s
      puts evaluator.toMatrixString.to_s
    end
  end
  
	class WekaClassifier	
    attr_accessor :data, :native_classifier
    def initialize(options=nil)
    end
    
    def get_default_evaluator
      WekaEvaluator.new(self, self.data)
    end
    
    def start_trainning(dataset_path)
    end
    
    def classify(unlabeled_instances_path)
    end
	end
	
	class WekaNaiveBayes < WekaClassifier
		

		def start_trainning(dataset_path)
			include_class 'weka.core.converters.ConverterUtils'
			include_class 'java.io.FileReader'
			include_class 'weka.classifiers.bayes.NaiveBayes'
			include_class 'weka.core.Instances'
			include_class 'weka.core.SerializationHelper'
			@native_classifier = NaiveBayes.new()
			dataset_source = ConverterUtils::DataSource.new(dataset_path)
			@data = dataset_source.getDataSet()
			@data.setClassIndex(@data.numAttributes() - 1)
			@native_classifier.buildClassifier(@data)
			SerializationHelper.write("./ml_models/naiveBayes.model", @native_classifier)
		end
	end
  
  class WekaJ48 < WekaClassifier
  
		def start_trainning(dataset_path)
			include_class 'weka.core.converters.ConverterUtils'
			include_class 'java.io.FileReader'
			include_class 'weka.classifiers.bayes.NaiveBayes'
			include_class 'weka.core.Instances'
			include_class 'weka.core.SerializationHelper' 
      include_class 'weka.classifiers.trees.J48'
			@native_classifier = J48.new()
      @native_classifier.setUnpruned(true)
			dataset_source = ConverterUtils::DataSource.new(dataset_path)
			@data = dataset_source.getDataSet()
			@data.setClassIndex(@data.numAttributes() - 1)
			@native_classifier.buildClassifier(@data)
			SerializationHelper.write("./ml_models/j48.model", @native_classifier)
		end
    
  end
  class LibSVMClassifier < WekaClassifier
  
    def initialize(options=nil)
      unless options
        options = ["-S 0", "-K 3", "-D 3",
        "-G 0.0", "-R 0.0", "-N 0.5", 
        "-M 40.0", "-C 1.0", "-E 0.0010",
        "-P 0.1", "-Z", "-B" ]
      end
      require 'java'
      if !$CLASSPATH.select{|path| path.include?("libsvm.jar")}.empty?
        $CLASSPATH << './lib/weka/libSVM.jar'
        require jar
      end      
      require './lib/weka/weka.jar'
      require './lib/weka/libsvm.jar'
      include_class 'weka.classifiers.functions.LibSVM'
      include_class 'weka.core.converters.ConverterUtils'
      include_class 'java.io.FileReader'
      include_class 'weka.classifiers.bayes.NaiveBayes'
      include_class 'weka.core.Instances'
      include_class 'weka.core.SerializationHelper'
      @native_classifier = LibSVM.new()
      @native_classifier.setOptions(options)
    end
    
    def start_trainning(dataset_path)
      dataset_source = ConverterUtils::DataSource.new(dataset_path)
      @data = dataset_source.getDataSet()
      @data.setClassIndex(@data.numAttributes() - 1)      
      @native_classifier.buildClassifier(@data)
			SerializationHelper.write("./ml_models/SVM.model", @native_classifier)
		end
  end
end