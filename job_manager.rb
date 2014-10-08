require 'rubygems'
require './lib/mysql-connector-java-5.1.18-bin'
require 'jdbc/mysql'
require 'generic_relation_extractor.rb'

# Classe que executa um processo ruby para extração de features dos exemplos
# armazenados em um banco de dados.

module JobManager
    # import da classe do driver jdbc para o mysql
    java_import 'com.mysql.jdbc.Driver'
    
    module JavaSql
		include_package 'java.sql'
	end
    
    # recupera uma conexão para um dataset de exemplos
    def self.get_connection_pedro_dataset
        if(@@conn_pedro_dataset.nil?)
            mysql_driver = Driver.new()
            puts "DATABASE ADDRESS:#{@@database_address}"
            @@conn_pedro_dataset ||= mysql_driver.connect("jdbc:mysql://#{@@database_address.strip}:3306/pedro_dataset?user=root&password=1234", nil)
        end
        @@conn_pedro_dataset
    end

    def self.get_connection_my_dataset
        mysql_driver = Driver.new()
        puts "DATABASE ADDRESS:#{@@database_address}"
        @@conn_my_dataset ||= mysql_driver.connect("jdbc:mysql://#{@@database_address.strip}:3306/my_dataset?user=root&password=1234", nil)
        @@conn_my_dataset
    end

    def self.find_matches(db)
        @@database_address = db
        get_connection_pedro_dataset
        get_connection_my_dataset
        query = "SELECT distinct source_page FROM sentences"
        result_set = @@conn_my_dataset.prepareStatement(query).executeQuery()

        while result_set.next do
            entity_1 = result_set.getString(1)
            query_pedro_dataset = "SELECT distinct class_1 from examples where entity_1 like '%" + entity_1.scan(/\//).last
            pedro_result = @@conn_pedro_dataset.prepareStatement(query_pedro_dataset).executeQuery()
            while pedro_result.next do
                class_1 = pedro_result.getString(1)
                puts class_1
                insert = "update uri_classes set pedro_class='#{class_1}' where uri = '#{source_page}'"
                @@conn_my_dataset.executeUpdate(insert)
            end

        end
        available_tasks

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

    # Inicia várias threads que irão extrair features dos exemplos e armazená-las em um banco de dados
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

    # Recupera a próxima tarefa no banco
    def self.find_next_available_task
        mysql_connection = get_connection_pedro_dataset
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
        mysql_connection = get_connection_pedro_dataset
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
        mysql_connection = get_connection_pedro_dataset
        
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
        mysql_connection = get_connection_pedro_dataset
        
        statement = mysql_connection.createStatement()
        statement.executeUpdate(query)
    end
    
    def self.count_sentences
        mysql_connection = get_connection_pedro_dataset
        query = "select count(*) from examples s"
        result_set = mysql_connection.prepareStatement(query).executeQuery()
        result_set.next()
        result_set.getInt(1)
    end
    
    def self.allocate_task(task)
        change_task_status(task.offset, "ONPROGRESS", "")
    end
    start_jobs(ARGV[0].to_i, ARGV[1].to_s)
end