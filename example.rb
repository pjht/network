require_relative "netlib.rb"
ArpUtils.log_arp=true
cable=EtherCable.new()
dev1=EtherSocket.new(cable,"d2:f5:8a:c4:22:56")
dev2=EtherSocket.new(cable,"d2:f5:8a:22:65:4c")
dev3=EtherSocket.new(cable,"d2:f5:8a:34:6d:7e")
ipdriv1=IPDriver.new(dev1,"192.168.0.34",true)
ipdriv2=IPDriver.new(dev2,"192.168.0.40",true)
ipdriv3=IPDriver.new(dev3,"192.168.0.56",true)
ipdriv3.register_callback(254) do |from,data|
  puts "#{data} from #{from}"
end
ipdriv1.send_packet("Hello","192.168.0.56")
ipdriv2.send_packet("Hi","192.168.0.56")
