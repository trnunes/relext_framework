require 'rubygems'
require './lib/mysql-connector-java-5.1.18-bin'
require 'jdbc/mysql'
require 'generic_relation_extractor.rb'
module JobManager
    java_import 'com.mysql.jdbc.Driver'
    
    module JavaSql
		include_package 'java.sql'
	end
 
    def self.get_connection_pedro_dataset
        mysql_driver = Driver.new()
        puts "DATABASE ADDRESS:#{@@database_address}"
        @@conn_pedro_dataset ||= mysql_driver.connect("jdbc:mysql://#{@@database_address.strip}:3306/pedro_dataset?user=root&password=1234", nil)
        @@conn_pedro_dataset
    end
    def self.get_connection_my_dataset
        mysql_driver = Driver.new()
        puts "DATABASE ADDRESS:#{@@database_address}"
        @@conn_my_dataset ||= mysql_driver.connect("jdbc:mysql://#{@@database_address.strip}:3306/my_dataset?user=root&password=1234", nil)
        @@conn_my_dataset
    end

    def self.find_matches(db)
        File.open("pedro_types", 'w') {|f| }
        @@database_address = db
        get_connection_pedro_dataset
        get_connection_my_dataset
        load_my_entites
        load_entity_class_hash
        puts "MATCHING ENTITIES"
        @@entities.each{|entity|
            entity_label = '/' << entity.split(/\//).last
            puts entity_label
            if(!@@classes_by_entity[entity_label].nil?)
                File.open("pedro_types", 'a') {|f| f.write(entity + " " + @@classes_by_entity[entity_label] + "\n")}
            end
        }
    end

    def self.load_my_entites
        query = "SELECT distinct source_page FROM sentences"
        result_set = @@conn_my_dataset.prepareStatement(query).executeQuery()
        @@entities = []
        puts "LOADING SOURCE ENTITIES"
        while result_set.next do
            @@entities << result_set.getString(1)
        end
        puts "LOADING TARGET ENTITIES"
        query = "SELECT distinct target_page FROM sentences"
        result_set = @@conn_my_dataset.prepareStatement(query).executeQuery()
        while result_set.next do
            @@entities << result_set.getString(1)
        end
        @@entities.uniq!
    end
    
    def self.insert(db)
        lines = File.readlines("pedro_types")
        @@database_address = db
        get_connection_my_dataset
        lines.each{|l|
            uri, klass = l.split(" ")
            update_query = "update uri_classes set pedro_class='#{klass}' where uri='#{uri}'"
            @@conn_my_dataset.prepareStatement(update_query).executeUpdate()
        }
    end

    def self.load_entity_class_hash
        query = "SELECT distinct entity_1, class_1 from examples"
        result_set = @@conn_pedro_dataset.prepareStatement(query).executeQuery()
        @@classes_by_entity = {}
        puts "BUILDING ENTITIES 1 HASH"
        while result_set.next do
            entity_1 = result_set.getString(1)
            class_1 = result_set.getString(2)
            @@classes_by_entity[entity_1] = class_1
        end
        
        query = "SELECT distinct entity_2, class_2 from examples"
        result_set = @@conn_pedro_dataset.prepareStatement(query).executeQuery()
        puts "BUILDING ENTITIES 2 HASH"
        while result_set.next do
            entity_1 = result_set.getString(1)
            class_1 = result_set.getString(2)
            @@classes_by_entity[entity_1] = class_1
        end
        
    end

    class Task
        attr_accessor :offset, :limit, :status
    end

    def self.create_tasks(number_of_tasks)
        
        offset = 0
        
        total_of_sentences = count_sentences
        
        amount_of_work_per_task = total_of_sentences/number_of_tasks
        puts amount_of_work_per_task.to_i
        number_of_tasks.times{|index|
            create_new_task(offset, amount_of_work_per_task)
            offset += amount_of_work_per_task
        }
        
    end

    def self.start_jobs(number_of_jobs, database_address)
        @@database_address = database_address
        threads = []
        tasks = find_available_tasks(number_of_jobs)
        tasks.each{|task|
            threads << Thread.new(task){|task|
                GenericRelationExtractor::init(database_address)
                begin
                    allocate_task(task)
                    
                    return_msg = GenericRelationExtractor::extract_features(task.offset, task.limit)
                    if(return_msg[0] == "SUCCESS")
                        register_success(task)
                    else
                        register_failure(task, return_msg[1])
                        e = return_msg[1]
                    end
                    task = find_next_available_task
                end until(task.nil?)
            }

        }

        threads.each{|t| t.join}

    end

    def self.find_next_available_task
        mysql_connection = get_connection
        query = "SELECT * FROM tasks WHERE status='AVAILABLE' LIMIT #{1}"
        result_set = mysql_connection.prepareStatement(query).executeQuery()
        available_task = nil
        while result_set.next do
            task = Task.new()
            task.offset = result_set.getInt(1)
            task.limit = result_set.getInt(2)
            task.status = result_set.getString(3)
            available_task = task
        end
        available_task
    end

    def self.find_available_tasks(number_of_jobs)
        mysql_connection = get_connection
        query = "SELECT * FROM tasks WHERE status='AVAILABLE' LIMIT #{number_of_jobs}"
        result_set = mysql_connection.prepareStatement(query).executeQuery()
        available_tasks = []
        while result_set.next do
            task = Task.new()
            task.offset = result_set.getInt(1)
            task.limit = result_set.getInt(2)
            task.status = result_set.getString(3)
            available_tasks << task
        end
        available_tasks
    end
    
    def self.create_new_task(offset, limit)
        mysql_connection = get_connection
        
        query = "insert into tasks values(?, ?, ?)"
 
        prepared_statement = mysql_connection.prepareStatement(query)
        prepared_statement.setInt(1, offset)
        prepared_statement.setInt(2, limit)
        prepared_statement.setString(3, "AVAILABLE")
        
        prepared_statement.executeUpdate()
    end
    
    def self.register_success(task)
        change_task_status(task.offset, "SUCCESS", "")
    end

    def self.register_failure(task, message)
        change_task_status(task.offset, "FAILURE", "")

    end
    
    def self.change_task_status(task_offset, new_status, message)
        query = "UPDATE tasks SET status='#{new_status}', message='#{message}' WHERE offset=#{task_offset}"
        mysql_connection = get_connection
        
        statement = mysql_connection.createStatement()
        statement.executeUpdate(query)
    end
    
    def self.count_sentences
        mysql_connection = get_connection
        query = "select count(*) from examples s"
        result_set = mysql_connection.prepareStatement(query).executeQuery()
        result_set.next()
        result_set.getInt(1)
    end
    
    def self.allocate_task(task)
        change_task_status(task.offset, "ONPROGRESS", "")
    end
    insert(ARGV[0].to_s)
end