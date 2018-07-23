require_relative "netlib.rb"
ArpUtils.log_arp=true
cable=EtherCable.new()
dev1=EtherSocket.new(cable,"d2:f5:8a:c4:22:56")
dev2=EtherSocket.new(cable,"d2:f5:8a:22:65:4c")
dev3=EtherSocket.new(cable,"d2:f5:8a:34:6d:7e")
ipdriv1=IPDriver.new(dev1,"192.168.0.34",true)
ipdriv2=IPDriver.new(dev2,"192.168.0.40",true)
ipdriv3=IPDriver.new(dev3,"192.168.0.56",true)
udpdriv1=UDPDriver.new(ipdriv1,true)
udpdriv2=UDPDriver.new(ipdriv2,true)
udpdriv3=UDPDriver.new(ipdriv3,true)
udpdriv1.register_callback do |from_ip,from_port,to_port,data|
  puts "#{data} from #{from_ip}:#{from_port} on port #{to_port}"
end
udpdriv2.register_callback do |from_ip,from_port,to_port,data|
  puts "#{data} from #{from_ip}:#{from_port} on port #{to_port}"
end
udpdriv3.register_callback do |from_ip,from_port,to_port,data|
  puts "#{data} from #{from_ip}:#{from_port} on port #{to_port}"
end
numb_to_ip={"1"=>"192.168.0.34","2"=>"192.168.0.40","3"=>"192.168.0.56"}
numb_to_driv={"1"=>udpdriv1,"2"=>udpdriv2,"3"=>udpdriv3}
while true
  print "Sending device(1,2,or 3):"
  from=numb_to_driv[gets.chomp]
  print "Receiving device(1,2,or 3):"
  to_ip=numb_to_ip[gets.chomp]
  print "From port:"
  from_port=gets.chomp!.to_i
  print "To port:"
  to_port=gets.chomp!.to_i
  print "Message:"
  message=gets.chomp!
  from.send_packet(message,to_ip,from_port,to_port)
end
