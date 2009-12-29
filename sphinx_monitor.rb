require 'time'

class SphinxMonitor < Scout::Plugin
  def build_report
     needs "elif"
     
     #add option for searchd.log to get data for index rotations
     search_log_path = option(:query_log_path)
     
     #add an option to specify the query log path
     query_log_path = option(:query_log_path)
     
     last_run = memory(:last_request_time) || Time.now
     
     #in seconds or amount/second
     report_data = {
       :num_queries => 0,
       :average_query_time => 0,
       :average_results_returned => 0,
       :index_rebuilds => 0,
       :average_time_per_rebuild => 0
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
         if line_data.timestamp.to_f <= last_run
           break
         else
           queries+=1
           total_query_time += line_data.time_spent
           total_results_returned += line_data.results_returned
         end
       end
     
       if queries > 0 
         report_data[:num_queries] = queries
         report_data[:average_query_time] = sprintf("%.2f", total_query_time/queries)
         report_data[:average_results_returned] = sprintf("%.2f", total_results_returned/queries)
       end
     rescue Errno::ENOENT => error
       return error("Unable to find the query log file", "Could not find the query log at the specified path: #{option(:query_log_path)}.")
     rescue Exception => error
       return error("Error while processing query log:\n#{error.class}: #{error.message}", error.backtrace.join("\n"))
     end
     
     #calculate the index rotation stats, only for index rotations that occur completely in the interval
     total_rotations = 0
     total_length_rotations = 0
     finish = nil
     begin
       Elif.foreach(search_log_path) do |line|
         line_data = parse_query_line(line)
         if line_data.timestamp.to_f <= last_run
           break
         else
           if finish
             if line_data.step == :start
               total_rotations += 1
               total_length_rotations += finish.to_f - line_data.timestamp.to_f
               finish = nil
             end
           else
             finish = line_data.timestamp if line_data.step == :finish
           end
         end
       end
       
       if total_rotations > 0
         report_data[:index_rebuilds] = total_rotations
         report_data[:average_time_per_rebuild] = sprintf("%.2f", total_rotations/total_length_rotations)
       end
     rescue Errno::ENOENT => error
       return error("Unable to find the searchd log file", "Could not find the searchd log at the specified path: #{option(:query_log_path)}.")
     rescue Exception => error
       return error("Error while processing searchd log:\n#{error.class}: #{error.message}", error.backtrace.join("\n"))
     end
     remember(:last_request_time, Time.now)
     report(report_data)
  end
private

  #[Mon Dec 28 06:57:18.968 2009] 0.004 sec [ext/3/rel 1 (0,1000) @second_category_id] [main] @tags_delimited(incandescent lamping wall mount visa lighting northridge)
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
  
end