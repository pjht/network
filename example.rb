require_relative "netlib.rb"
require "packetfu"
cable=EtherCable.new("etherlog.log")
dev1=EtherSocket.new(cable,"d2:f5:8a:c4:22:56")
dev2=EtherSocket.new(cable,"d2:f5:8a:22:65:4c")
ArpUtils.add_arp_resp(dev2,"192.168.0.56")
ipsock=MyIPSocket.new(dev1,"192.168.0.34")
ipsock2=MyIPSocket.new(dev2,"192.168.0.56")
ipsock.send_packet("hello","192.168.0.56")
ipsock.send_packet("hi","192.168.0.56")
