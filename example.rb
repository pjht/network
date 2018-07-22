require_relative "netlib.rb"
cable=EtherCable.new("etherlog.log")
dev1=EtherSocket.new(cable,[0,0,0,0,0,0])
dev2=EtherSocket.new(cable,[0,0,0,0,0,1])
dev3=EtherSocket.new(cable,[0,0,0,0,0,2])
dev1.register_callback do |packet|
  p packet
end
dev2.register_callback do |packet|
  p packet
  dev2.send_packet("hi",packet[0])
end
dev3.register_callback do |packet|
  p packet
  dev3.send_packet("hi",packet[0])
end
dev1.send_packet("hello",[0,0,0,0,0,1])
dev1.send_packet("hello",[0,0,0,0,0,2])
