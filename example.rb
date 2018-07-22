require_relative "netlib.rb"
ArpUtils.log_arp=true
cable=EtherCable.new()
dev1=EtherSocket.new(cable,"d2:f5:8a:c4:22:56")
dev2=EtherSocket.new(cable,"d2:f5:8a:22:65:4c")
ArpUtils.add_arp_resp(dev2,"192.168.0.56")
ipdriv1=IPDriver.new(dev1,"192.168.0.34",true)
ipdriv2=IPDriver.new(dev2,"192.168.0.56",true)
ipdriv1.send_packet("hello","192.168.0.56")
ipdriv1.send_packet("hi","192.168.0.56")
