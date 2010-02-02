#!/usr/bin/env ruby

require 'rubygems'
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
    puts Sanitize.clean(message)
    ## Create a new document to post to Solr
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.add {
        xml.doc_ {
          xml.field(:name => 'uuid') { xml.text uniqueid }
          xml.field(:name => 'sender') { xml.text sender }
          xml.field(:name => 'received') { xml.text "#{utc}Z" }
          xml.field(:name => 'message') { xml.text Sanitize.clean(message) }
          xml.field(:name => 'channel') { xml.text channel }
        }
      }
    end
    File.open('/tmp/update.xml', 'w') {|f| f.write(builder.to_xml.gsub(/\n/,''))}
    
    ## Post the new document to Solr host conf[:host]
    `curl -s #{conf[:host]} --data-binary @/tmp/update.xml -H 'Content-type:text/xml; charset=utf-8'`    
  end
end

`curl -s #{conf[:host]} --data-binary '<commit/>' -H 'Content-type:text/xml; charset=utf-8'`