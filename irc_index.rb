#!/usr/bin/env ruby

require 'rubygems'
require 'sanitize'
require 'nokogiri'
require 'getopt/long'
require 'uuid'
require 'rsolr'

opts = Getopt::Long.getopts(
  ['-f', Getopt::REQUIRED],
  ['-h', Getopt::REQUIRED]
)

conf = {}
opts.each do |opt, arg|
  case opt
  when 'f'
    conf[:file] = arg
  when 'h'
    conf[:host] = arg
  end
end

unless conf.keys.size == 2
  puts "File and host arguments required"
  exit()
end

rsolr = RSolr.connect(:url => 'http://localhost:8080/solr')

document = Nokogiri::XML(File.read(conf[:file]))
uuid = UUID.new
channel = conf[:file].match(/^(.*)\/(.*)?\s/)[2].gsub(/#/,'')

envelopes = document.search('envelope')
envelopes.each do |envelope|
  ## Dig out the contents we want to index
  sender = envelope.search('sender').children.text
  messages = envelope.search('message')
  
  messages.each do |message|
    uniqueid = uuid.generate
    
    ## Transform the received time into solr format eg. 1995-12-31T23:59:59Z
    ## 010-01-11 14:09:28 -0700 
    received = message['received']
    date = DateTime.parse(received)
    utc = date.new_offset(Date.time_to_day_fraction(-7,0,0))
    
    message = message.children.text
    #Add a new document for the message.
    rsolr.add(:uuid => uniqueid, :sender => sender, :received => "#{utc}Z", 
              :message => Sanitize.clean(message), :channel => channel)
  end
end

rsolr.commit()

puts conf[:file]