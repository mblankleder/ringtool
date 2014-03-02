#!/usr/bin/env ruby

# use dynect dns
# cassandra 1.1.x
# resolves the ip address and shows the node name instead

def check_gems()
  puts "[INFO] Checking installed gems"
  gems = %w(text-table dynect_rest)
  gems.each do |g|
    c = `gem list #{g}`
    str =  c.split(" ").first.to_s
    if gems.include?(str)
      puts "[OK] #{g}"
    else
      puts "[INFO] Installing #{g}"
      `sudo gem install --no-rdoc --no-ri #{g}`
    end
  end
end

check_gems()

require 'rubygems'
require 'text-table'
require 'resolv'
require 'dynect_rest'

title = ["Address", "Rack", "Status", "State", "Load", "Owns", "Token"]
@tmp_file = '/tmp/ringtool.tmp'
@server_to_connect = 'cassandra node to connect'
@keyspace_name = 'your keyspace name'

devops_home = ENV['DEVOPS_PATH']
if ENV['DEVOPS_PATH'].nil? || ENV['DEVOPS_PATH'] == ""
  devops_home = "/opt/devops"
end

dns_creds_file = "#{devops_home}/env/dns"

class DataLine
  attr_accessor :address
  attr_accessor :rack
  attr_accessor :status
  attr_accessor :state
  attr_accessor :ld
  attr_accessor :eff_own
  attr_accessor :token
    
  def initialize(address, rack, status, state, ld, eff_own, token)
    @address=address
    @rack=rack
    @status=status
    @state=state
    @ld=ld
    @eff_own=eff_own
    @token=token
  end
end

def export_vars(file)
  if File.exist?(file)
    File.readlines(file).each do |line|
      unless line.nil?
        values = line.split("=")
        # get rid of unwanted characters
        ENV[values[0]] = values[1].gsub(/\n/,"").gsub(/\"/,"").strip
      end
    end
  else
    puts "[ERROR] The file #{file} doesn't exist"
    exit 1
  end
end

def generate_tmp_file()
  nt=`which nodetool`.gsub(/\n/,"")
  if File.exist?(nt)
    puts "[INFO] Gathering data"
    `#{nt} -h #{@server_to_connect} ring #{@keyspace_name} > #{@tmp_file}`
  else
    puts "[ERROR] Couldn't find nodetool command"
    exit 1
  end
end

def ring_data()
  puts "[INFO] Extracting ring data from temp file"
  ring_ips = Hash.new
  File.open("#{@tmp_file}").each do |line|
    if line.match(/([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})/)
      ip = line.split(" ")[0]
      host = Resolv.new.getname(ip)
      ring_ips[ip] = host
    end
  end
  return ring_ips
end

def records_from_dns()
  puts "[INFO] Getting records from dns"
  aux = Hash.new
  dyn = DynectRest.new(ENV['DYNECT_CUST'], ENV['DYNECT_USER'], ENV['DYNECT_PASS'], ENV['DYNECT_ZONE'], true)
  record = dyn.get("AllRecord/#{ENV['DYNECT_ZONE']}")
  record.each do |r|
    if r.include?(".cassie.")
      id = "#{r.split('/')[-1]}"
      fqdn = r.split('/')[-2]
      host = dyn.get("CNAMERecord/#{ENV['DYNECT_ZONE']}/#{fqdn}/#{id}")['rdata']['cname'][0..-2]
      aux[host] = fqdn
    end
  end
  return aux
end

def reformat_line(ring_d,dns_d)
  puts "[INFO] Re formatting lines"
  line_nodes = Array.new
  File.open("#{@tmp_file}").each do |line|
    if line.match(/([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})/)
      l = line.gsub(/\n/,"")
      ll = l.split("\s")
      n_name = dns_d[ring_d[ll[0]]]
      load_m = "#{ll[4]} #{ll[5]}"
      dl = DataLine.new(n_name,ll[1],ll[2],ll[3],load_m,ll[6],ll[7])
      line_nodes << dl
    end
  end
  return line_nodes
end

export_vars(dns_creds_file)
generate_tmp_file()
r_dns = records_from_dns()
r_data = ring_data()
new_lines = reformat_line(r_data,r_dns)

# table creation
aux = Array.new
new_lines.each do |obj|
    aux << obj.address
    aux << obj.rack
    aux << obj.status
    aux << obj.state
    aux << obj.ld
    aux << obj.eff_own
    aux << obj.token
end
aux2 = Array.new
aux2 << title
aux.each_slice(7) do |address, rack, status, state, ld, eff_own, token|
  if address != nil
    n = [address.split('.yourdomain.com').first, rack, status, state, ld, eff_own, token]
    aux2 << n
  end
end
puts aux2.to_table(:first_row_is_head => true)

File.delete(@tmp_file)
