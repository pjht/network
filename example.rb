require_relative "netlib.rb"
ArpUtils.log_arp=true
cable=EtherCable.new()
dev1=EtherSocket.new(cable,"d2:f5:8a:c4:22:56")
dev2=EtherSocket.new(cable,"d2:f5:8a:22:65:4c")
dev3=EtherSocket.new(cable,"d2:f5:8a:34:6d:7e")
ipdriv1=IPDriver.new(dev1,"192.168.0.34",true)
ipdriv2=IPDriver.new(dev2,"192.168.0.40",true)
ipdriv3=IPDriver.new(dev3,"192.168.0.56",true)
ipdriv1.register_callback(254) do |from,data|
  puts "Got #{data} from #{from}"
end
ipdriv2.register_callback(254) do |from,data|
  puts "Got #{data} from #{from}"
end
ipdriv3.register_callback(254) do |from,data|
  puts "Got #{data} from #{from}"
end
numb_to_ip={"1"=>"192.168.0.34","2"=>"192.168.0.40","3"=>"192.168.0.56"}
numb_to_driv={"1"=>ipdriv1,"2"=>ipdriv2,"3"=>ipdriv3}
while true
  print "From(1,2,or 3):"
  from=numb_to_driv[gets.chomp]
  print "To(1,2,or 3):"
  to=numb_to_ip[gets.chomp]
  print "Message:"
  message=gets.chomp!
  from.send_packet(message,to)
end
