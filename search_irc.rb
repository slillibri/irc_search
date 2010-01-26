#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'uri'
require 'rsolr'
require 'getoptlong'
require 'pp'

opts = GetoptLong.new(
  ['--channel', '-c', GetoptLong::REQUIRED_ARGUMENT],
  ['--query', '-q', GetoptLong::REQUIRED_ARGUMENT],
  ['--rows', '-r', GetoptLong::REQUIRED_ARGUMENT])
  
conf = {:rows => 10}
begin
  opts.each do |opt,arg|
    case opt
    when '--channel'
      conf[:channel] = arg
    when '--query'
      conf[:query] = arg
    when '--rows'
      conf[:rows] = arg
    end
  end
rescue Exception => e
  exit
end

##Build search query
if (conf[:channel])
  searchQuery =  "channel:#{conf[:channel]} AND "
end
if (conf[:query])
  searchQuery = "#{searchQuery}(#{conf[:query]})"
end

##Query the local solr server
solr = RSolr.connect(:url => 'http://localhost:8080/solr')
results = solr.select(:q => searchQuery, :rows => conf[:rows], :sort => "received asc")

results['response']['docs'].each do |res|
  date = DateTime.parse(res['received']).new_offset(Date.time_to_day_fraction(-7,0,0))
  puts "\033[1m#{res['sender']}\033[0m on #{date.strftime('%Y-%m-%d %H:%M:%S')} said \033[1m#{res['message']}\033[0m in #{res['channel']}"
end