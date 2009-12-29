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
       :average_query_rate => 0,
       :average_query_time => 0,
       :average_results_returned => 0,
       :index_rebuild => 0,
       :average_time_per_rebuild => 0
     }
     
     #calculate the stats based on queries, rate, avg_time and average results returned
     
     #Load each line from the log in if it happened after the last request used in the previous report
     to_process = []
     Elif.foreach(query_log_path) do |line|
       #extract the date form the line and make sure it occured after last_run
       
     end
  end
private
  QueryData = Struct.new(:timestap, :time_spent, :results_returned)
  #based off of from http://kobesearch.cpan.org/htdocs/Sphinx-Log-Parser/Sphinx/Log/Parser.pm.html
  def parse_searchd_line(line)
    #extract doesnt need to be recreated everythime the method is called
    time_stamp = Time.parse(line.split(']')[0].gsub('[',''))
    QueryData.new(time_stamp,2,3)
  end
  
end