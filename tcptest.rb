require_relative "netlib.rb"
# ArpUtils.log_arp=true
cable=EtherCable.new(true,"tcp.pcapng",true)
dev1=EtherSocket.new(cable,"d2:f5:8a:c4:22:56")
dev2=EtherSocket.new(cable,"d2:f5:8a:22:65:4c")
ipdriv1=IPDriver.new(dev1,"192.168.0.34")
ipdriv2=IPDriver.new(dev2,"192.168.0.40")
tcpdriv1=TCPDriver.new(ipdriv1,true)
tcpdriv2=TCPDriver.new(ipdriv2,true)
tcpsock=TCPSocket.new(tcpdriv1,"192.168.0.40",56)
tcpsock.send "Hello"
