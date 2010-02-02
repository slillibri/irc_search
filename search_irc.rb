#!/usr/bin/env ruby

require 'rubygems'
require 'rsolr'
require 'getopt/long'

opts = Getopt::Long.getopts(
  ['--channel', '-c', Getopt::REQUIRED],
  ['--query', '-q', Getopt::REQUIRED],
  ['--rows', '-r', Getopt::REQUIRED],
  ['--startDate', '-s', Getopt::REQUIRED])
  
conf = {:rows => 10}
begin
  opts.each do |opt,arg|
    case opt
    when 'channel'
      conf[:channel] = arg
    when 'query'
      conf[:query] = arg
    when 'rows'
      conf[:rows] = arg
    when 'startDate'
      conf[:start] = arg
    end
  end
rescue Exception => e
  exit
end

##Build search query
queryItems = []
if (conf[:channel])
  queryItems.push("channel:#{conf[:channel]}")
end
if (conf[:query])
  queryItems.push("#{conf[:query]}")
end
if (conf[:start])
  date = DateTime.parse("#{conf[:start]}T00:00:00-7:00").new_offset
  dateString = date.to_s.gsub(/\+00:00/,'Z')
  queryItems.push("received:[#{dateString} TO *]")
end

query = queryItems.join(' AND ')

##Query the local solr server
solr = RSolr.connect(:url => 'http://localhost:8080/solr')
results = solr.select(:q => query, :rows => conf[:rows], :sort => "received asc")

results['response']['docs'].each do |res|
  received = DateTime.parse(res['received']).new_offset(Date.time_to_day_fraction(-7,0,0))
  puts "\033[1m#{res['sender']}\033[0m on #{received.strftime('%Y-%m-%d %H:%M:%S')} said \033[1m#{res['message']}\033[0m in #{res['channel']}"
end