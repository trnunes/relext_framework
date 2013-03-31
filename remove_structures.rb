		def remove_structures(delimiters, text)
      delimiters_count = 0
      while delimiters_count < delimiters.size do
        begin_markup = delimiters[delimiters_count][0]
        end_markup = delimiters[delimiters_count][1]
        markup_begin_condition = ""
        for markup_index in (0..begin_markup.size-1)
          markup_part = begin_markup[markup_index]
          markup_begin_condition << "text[i+#{markup_index}].chr == #{markup_part}.chr&&"
        end
        #removing the last && from the two final string pos
        markup_begin_condition[markup_begin_condition.size - 1] = ""
        markup_begin_condition[markup_begin_condition.size - 1] = ""
        # puts markup_begin_condition
        markup_end_condition = ""
        for markup_index in (0..end_markup.size-1)
          markup_part = end_markup[markup_index]
          markup_end_condition << "text[i+#{markup_index}].chr == #{markup_part}.chr&&"
        end
        #removing the last && from the two final string pos
        markup_end_condition[markup_end_condition.size - 1] = ""
        
        markup_end_condition[markup_end_condition.size - 1] = ""
        # puts markup_end_condition
        text_copy = text.dup
        template = ""
        stack = []
        max_markup_size = [begin_markup.size, end_markup.size].max
        iteration = 0
        i = 0
        while (i < text.size) do
          
          File.open("./log/structure_remotion.log", 'a'){|w| w.write("  CHAR ANALYSED: #{text[i].chr}\n")} 
          if(eval(markup_begin_condition))    
            File.open("./log/structure_remotion.log", 'a'){|w| w.write("BEGIN TEMPLATE\n")}
            stack.push("template_begin_found")
            iteration = i
          end
          template << text[i].chr if !stack.empty?        
          
          if(eval(markup_end_condition) && iteration != i)
            File.open("./log/structure_remotion.log", 'a'){|w| w.write("END TEMPLATE, POPPING\n")}
            iteration = 0
            stack.pop
            for c in(1..max_markup_size-1)
                template << text[i+c].chr                
            end
            if stack.empty?
              
              # puts template
              # puts "include template: #{text_copy.include?(template)}"
              
              text_copy.gsub!(template, "")
              
              File.open("./log/structure_remotion.log", 'a'){|w| w.write("TEMPLATE: #{template}\n")}
              File.open("./log/structure_remotion.log", 'a'){|w| w.write("TEXT: #{text_copy}\n\n")}
              
              # puts text
              puts ""
              template = ""              
            end
            i += max_markup_size
         
          else
            i+=1
          end
        end
        text = text_copy
        
        delimiters_count +=1
      end
       puts text
      text
		end		
text = '{{Infobox musical artist <!-- See Wikipedia:WikiProject Musicians -->
| name                = John Leventhal
| image                 = JL_Wiki_1.png
| caption            = 
| image_size            = <!-- Only for images narrower than 220 pixels -->
| background          = non_vocal_instrumentalist
| birth_name          = 
| alias               = 
| Born                = {{birth date and age|1952|12|18|mf=y}}<br /><small>[[New York City, New York|New York City]], [[New York]]<br />[[United States]]</small>
| death_date                = 
| instrument          = [[Guitar]], [[bass guitar]], [[keyboard instruments]], [[Drum kit|drums]], [[Audio engineering|Audio engineer]]
| genre               = [[Country music|Country]]
| occupation          = [[Musician]], <br/>[[Composer]]<br/>[[Record producer]]
| years_active        = 
| label               = 
| associated_acts     = [[Rosanne Cash]]
| website                 =  
| notable_instruments = 
}}
[[File:LeventhalCash2.jpg|thumb|Leventhal with Rosanne Cash]]
John Leventhal (born December 18, 1952) is a [[Grammy Award]]-winning musician, producer, songwriter, and [[recording engineer]] who has produced albums for  [[Michelle Branch]], [[Rosanne Cash]], [[Marc Cohn]], [[Shawn Colvin]], [[Rodney Crowell]], [[Jim Lauderdale]], [[Joan Osborne]], [[Loudon Wainwright]], [[The Wreckers]] and many others. As a musician he has worked with all of the above as well as artists such as [[Jackson Browne]], [[Willie Nelson]], [[Bruce Hornsby]], [[Elvis Costello]], [[Dolly Parton]], [[Emmylou Harris]], [[Charlie Haden]], [[David Crosby]], [[Levon Helm]], [[Edie Brickell]], [[Paul Simon]], [[Patty Larkin]], [[Susan Tedeschi]], [[Steve Forbert]], [[Kelly Willis]] and [[Johnny Cash]]. As a songwriter he has had over 100 songs recorded by various artists. In 1998 he won a Grammy Award for Record and Song of the year for producing and co-writing the song "Sunny Came Home" (a 1997 hit for Colvin). Albums he has produced have been nominated for a total of 11 Grammy Awards.<ref>{{cite web|title=All Music|publisher=allmusic.com|accessdate=2010-01-26|url={{Allmusic|class=artist|id=p98008|pure_url=yes}}}}</ref> In 2005 he composed the score for the film ''[[Winter Solstice (film)|Winter Solstice]]''.<ref>{{cite web|title=Winter Solstice|publisher=TVGuide.com|accessdate=2010-01-26|url=http://movies.tvguide.com/winter-solstice/cast/137907}}</ref>

Leventhal lives with his wife [[Rosanne Cash]] and their children in [[New York City]].

==References==
{{reflist}}

==External links==

{{Grammy Award for Song of the Year 1990s}}
{{Grammy Award for Record of the Year 1990s}}

{{Persondata <!-- Metadata: see [[Wikipedia:Persondata]]. -->
| NAME              = Leventhal, John
| ALTERNATIVE NAMES =
| SHORT DESCRIPTION =
| DATE OF BIRTH     = December 18, 1952
| PLACE OF BIRTH    =
| DATE OF DEATH     =
| PLACE OF DEATH    =
}}
{{DEFAULTSORT:Leventhal, John}}
{| class="wikitable"
|-
! Header 1
! Header 2
! Header 3
|-
| row 1, cell 1
| row 1, cell 2
| row 1, cell 3
|-
| row 2, cell 1
| row 2, cell 2
| row 2, cell 3
|-
| row 3, cell 1
| row 3, cell 2
| row 3, cell 3
|}

[[Category:1952 births]]
[[Category:Living people]]
[[Category:American country guitarists]]
[[Category:American rock guitarists]]
[[Category:American record producers]]
[[Category:American session musicians]]
[[Category:Grammy Award winners]]
[[Category:People from Scarsdale, New York]]
[[Category:Songwriters from New York]]

{{US-record-producer-stub}}
{{US-rock-guitarist-stub}}'
# text = '<ref>{{cite web|title=All Music|publisher=allmusic.com|accessdate=2010-01-26|url={{Allmusic|class=artist|id=p98008|pure_url=yes}}}}</ref>KHHLK'
remove_structures([["{{", "}}", ]],text)

# require 'java'
# require './lib/weka/weka.jar'
# require './lib/weka/libsvm.jar'
# include_class 'weka.classifiers.functions.LibSVM'
# include_class 'weka.core.converters.ConverterUtils'
# include_class 'java.io.FileReader'
# include_class 'weka.classifiers.bayes.NaiveBayes'
# include_class 'weka.core.Instances'
# include_class 'weka.core.SerializationHelper'
# @native_classifier = LibSVM.new()
# @native_classifier.setOptions(["-S 0", "-K 3", "-D 3", "-G 0.0", "-R 0.0", "-N 0.5", "-M 40.0", "-C 1.0", "-E 0.0010", "-P 0.1", "-Z", "-B" ])
# dataset_source = ConverterUtils::DataSource.new("./trainning_data/dataset.csv")
# @data = dataset_source.getDataSet()
# @data.setClassIndex(@data.numAttributes() - 1)
# @native_classifier.buildClassifier(@data)
# include_class 'weka.classifiers.Evaluation'
# include_class 'java.util.Random'
# puts "Importei"
# evaluator = Evaluation.new(@data)
# puts "INSTANCIEI AVALIADOR"
# evaluator.crossValidateModel(@native_classifier, @data, 10, Random.new(1))
# puts evaluator.toMatrixString.to_s