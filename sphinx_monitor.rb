require 'time'
require 'elif'

class SphinxMonitor < Scout::Plugin
  
  def build_report
    
    #test command  = scout test sphinx_monitor.rb query_log_path=/Users/sam/Desktop/query.log.bak search_log_path=/Users/sam/Desktop/searchd.log.bak
    
     #taken from rails monitor
     #http://github.com/highgroove/scout-plugins/raw/master/rails_requests/rails_requests.rb
     patch_elif
     
     search_log_path = option(:search_log_path)
     
     query_log_path =  option(:query_log_path)
     
     #change 
     last_run = Time.now() - 14*3600 || memory(:last_request_time)
     
     
     error("LR #{search_log_path} #{query_log_path}")
     #in seconds or amount/second
     report_data = {
       :num_queries => 0,
       :average_query_time => 0,
       :average_results_returned => 0,
       :index_rebuilds => 0,
       :average_time_per_rebuild => 0,
     }
     
     #calculate the stats based on queries, rate, avg_time and average results returned
     
     #Load each line from the log in if it happened after the last request used in the previous report
     queries = 0
     total_query_time = 0
     total_results_returned = 0
     begin
       Elif.foreach(query_log_path) do |line|
         #extract the date form the line and make sure it occured after last_run
         line_data = parse_query_line(line)
         if line_data.timestamp.to_f <= last_run.to_f
           break
         else
           queries+=1
           total_query_time += line_data.time_spent
           total_results_returned += line_data.results_returned
         end
       end
     
       if queries > 0 
         report_data[:num_queries] = queries
         report_data[:average_query_time] = sprintf("%.4f", total_query_time/queries)
         report_data[:average_results_returned] = sprintf("%.4f", total_results_returned/queries)
       end
     rescue Errno::ENOENT => error
       return error("Unable to find the query log file", "Could not find the query log at the specified path: #{option(:query_log_path)}.")
     rescue Exception => error
       return error("Error while processing query log:\n#{error.class}: #{error.message}", error.backtrace.join("\n"))
     end
     
     #calculate the index rotation stats, only for index rotations that occur completely in the interval
     total_rotations = 0
     total_length_rotations = 0
     finish_time = nil
     begin
       Elif.foreach(search_log_path) do |line|
         line_data = parse_log_line(line)
         if line_data.timestamp.to_f <= last_run.to_f
           break
         else
           if finish_time
             if line_data.step == :start
               total_rotations += 1
               total_length_rotations += finish_time.to_f - line_data.timestamp.to_f
               finish_time = nil
             end
           else
             finish_time = line_data.timestamp if line_data.step == :finish
           end
         end
       end
       
       if total_rotations > 0
         report_data[:index_rebuilds] = total_rotations
         report_data[:average_time_per_rebuild] = sprintf("%.4f", total_length_rotations/total_rotations)
       end
     rescue Errno::ENOENT => error
       return error("Unable to find the searchd log file", "Could not find the searchd log at the specified path: #{option(:query_log_path)}.")
     rescue Exception => error
       return error("Error while processing searchd log:\n#{error.class}: #{error.message}", error.backtrace.join("\n"))
     end
     # the time the
     remember(:last_request_time, Time.now)
     report(report_data)
  end
private

  QueryData = Struct.new(:timestamp, :time_spent, :results_returned)
  
  LogData = Struct.new(:timestamp, :step)
  
  #based off of http://kobesearch.cpan.org/htdocs/Sphinx-Log-Parser/Sphinx/Log/Parser.pm.html
  def parse_query_line(line)
    time = line.match(/\[(.*?)\]/).captures.first
    time_spent = line.match(/\]\s([\d\.]+).*?\[/).captures.first
    results_returned = line.match(/\s(\d+)\s\(/).captures.first
    QueryData.new(Time.parse(time), time_spent.to_f, results_returned.to_i)
  end
  
  def parse_log_line(line)
    time = line.match(/\[(.*?)\]/).captures.first    
    step = if line.match('rotating finished')
      :finish
    elsif line.match('rotating indices')
      :start
    else
      :intermediate
    end
    LogData.new(Time.parse(time), step)
  end
  
  #taken from rails monitor
  #http://github.com/highgroove/scout-plugins/raw/master/rails_requests/rails_requests.rb
  def patch_elif
    if Elif::VERSION < "0.2.0"
      Elif.send(:define_method, :pos) do
        @current_pos +
        @line_buffer.inject(0) { |bytes, line| bytes + line.size }
      end
    end
  end
  
end