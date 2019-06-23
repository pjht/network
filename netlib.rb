require "packetfu"
class EtherSocket
  attr_reader :mac
  def initialize(cable,mac)
    @mac=mac
    @callbacks={}
    @cable=cable
    cable.add_device(self)
  end
  def send_packet(data,to,type)
    @cable.send_packet([@mac,to,type,data],self)
  end
  def register_callback(type,&block)
    if @callbacks[type]==nil
      @callbacks[type]=[]
    end
    @callbacks[type].push block
  end
  def got_packet(packet)
    return if packet[1]!=@mac and packet[1]!="ff:ff:ff:ff:ff:ff"
    if @callbacks[packet[2]]
      @callbacks[packet[2]].each { |cback| cback.call([packet[0],packet[3]]) }
    end
  end
end

class EtherCable
  def initialize(log=false,file=nil,clear=false)
    @socks=[]
    @log=log
    @file=file
    PacketFu::PcapFile.new.write(file) if clear
  end
  def add_device(socket)
    @socks.push(socket)
  end
  def send_packet(packet,sock)
    if @log
      pkt = PacketFu::EthPacket.new
      pkt.eth_saddr=packet[0]
      pkt.eth_daddr=packet[1]
      pkt.eth_proto=packet[2]
      pkt=PacketFu::Packet.parse(pkt.to_s+packet[3])
      p pkt
      if @file
        PacketFu::PcapFile.new().array_to_file({:file=>@file,:array=>[pkt],:append=>true})
      end
      # puts "Frame of type #{packet[2]} from #{packet[0]} to #{packet[1]}. Data:"
      # NetLib::show_data(packet[3])
    end
    @socks.each { |socket| next if sock==socket; socket.got_packet(packet) }
  end
end

class IPDriver
  def initialize(eth_sock,ip,log=false)
    @sock=eth_sock
    @ip=ip
    @resolved={}
    @log=log
    @packets=[]
    @callbacks={}
    ArpUtils.add_arp_resp(eth_sock,ip)
    eth_sock.register_callback(NetLib::ARP) do |packet|
      packet=ArpUtils::parse_arp_packet(packet)
      @resolved[packet[2]]=packet[0] if packet[3]==NetLib::ARP_RESP
    end
    eth_sock.register_callback(NetLib::IP) do |packet|
      packet=parse_ip_packet(packet)
      if @log
        $stdout.puts "IP packet of type #{packet[0]} to #{@ip} from #{packet[1]}. Data:"
        NetLib::show_data(packet[2])
      end
      if @callbacks[packet[0]]
        @callbacks[packet[0]].each { |cback| cback.call([packet[1],packet[2]]) }
      end
    end
  end
  def register_callback(type,&block)
    if @callbacks[type]==nil
      @callbacks[type]=[]
    end
    @callbacks[type].push block
  end
  def send_packet(msg,to,proto)
    packet=PacketFu::IPHeader.new
    packet.ip_saddr=@ip
    packet.ip_daddr=to
    packet.ip_proto=proto
    packet.body=msg
    packet.ip_recalc
    packet=packet.to_s
    if !@resolved[to]
      ArpUtils.send_arp(@sock,to)
      blah=0
      while !@resolved[to]
        blah=1+1
      end
    end
    @sock.send_packet(packet,@resolved[to],NetLib::IP)
  end
  private
  def parse_ip_packet(packet)
    mac_header=PacketFu::EthHeader.new()
    mac_header=mac_header.to_s
    packet=packet[1]
    packet=mac_header+packet
    ip_packet=PacketFu::IPPacket.new
    packet=ip_packet.read(packet)
    return [packet.ip_proto,packet.ip_saddr,packet.payload]
  end
end

class UDPDriver
  def initialize(driv,log=false)
    @driver=driv
    @log=log
    @callbacks={}
    driv.register_callback(NetLib::UDP) do |from,data|
      packet=parse_udp_packet(data)
      if @log
        $stdout.puts "UDP datagram from #{from}:#{packet[0]} on port #{packet[1]}. Data:"
        NetLib::show_data(packet[2])
      end
      if @callbacks[packet[1]]
        @callbacks[packet[1]].each { |cback| cback.call(from,packet[0],packet[2]) }
      end
      if @callbacks[65536]
        @callbacks[65536].each { |cback| cback.call(from,packet[0],packet[1],packet[2]) }
      end
    end
  end
  def register_callback(type=65536,&block)
    if @callbacks[type]==nil
      @callbacks[type]=[]
    end
    @callbacks[type].push block
  end
  def send_packet(data,to_ip,from_port,to_port)
    packet=PacketFu::UDPHeader.new
    packet.udp_src=from_port
    packet.udp_dst=to_port
    packet.body=data
    packet.udp_recalc
    packet=packet.to_s
    @driver.send_packet(packet,to_ip,NetLib::UDP)
  end
  def parse_udp_packet(packet)
    packet=PacketFu::UDPHeader.new.read(packet)
    return [packet.udp_src,packet.udp_dst,packet.body]
  end
end
class TCPDriver
  def initialize(device,log=false)
    @device=device
    @log=log
    @connections=[]
    device.register_callback(NetLib::TCP) do |from,data|
      packet,new_conn=parse_tcp_packet(from,data)
      if @log
        seq=packet[4][:last_seq]
        ack=packet[4][:last_ack]
        flags=flags_to_str(packet[2])
        str=""
        str="Data:" if packet[3].size>0
        $stdout.puts "TCP packet from #{from}:#{packet[0]} on port #{packet[1]}. Flags:#{flags} SEQ:#{seq} ACK:#{ack} #{str}"
        NetLib::show_data(packet[3])
      end
      if new_conn
        send_packet({:syn=>true,:ack=>true},packet[1])
      else
        unless packet[2].ack==1 and packet[2].syn==0
          send_packet({:ack=>true},packet[1])
        end
      end
    end
  end
  def connect(from_port,to_port,to_ip)
    connection={}
    connection[:from_port]=from_port
    connection[:last_ack]=0
    connection[:last_seq]=-1
    connection[:to_ip]=to_ip
    @connections[to_port]=connection
    send_packet({:syn=>true},to_port)
  end
  def send_packet(flags,to_port,data=nil)
    connection=@connections[to_port]
    packet=PacketFu::TCPHeader.new
    packet.tcp_src=connection[:from_port]
    packet.tcp_dst=to_port
    packet.tcp_seq=connection[:last_ack]
    if data
      size=data.bytesize
    else
      size=1
    end
    packet.tcp_ack=connection[:last_seq]+size
    packet.tcp_flags=PacketFu::TcpFlags.new(flags)
    if data
      packet.body=data
    end
    packet.tcp_recalc
    packet=packet.to_s
    @device.send_packet(packet,connection[:to_ip],NetLib::TCP)
  end
  def parse_tcp_packet(from,packet)
    packet=PacketFu::TCPHeader.new.read(packet)
    to_port=packet.tcp_dst
    connection=@connections[to_port]
    new_conn=false
    if !connection
      connection={}
      connection[:from_port]=packet.tcp_src
      connection[:to_ip]=from
      new_conn=true
    end
    connection[:last_seq]=packet.tcp_seq
    connection[:last_ack]=packet.tcp_ack
    @connections[to_port]=connection
    return [packet.tcp_src,packet.tcp_dst,packet.tcp_flags,packet.body,connection],new_conn
  end
  def flags_to_str(flag_data)
    flags=""
    if flag_data.syn==1
      flags+="SYN "
    end
    if flag_data.ack==1
      flags+="ACK "
    end
    if flag_data.fin==1
      flags+="FIN "
    end
    if flag_data.psh==1
      flags+="PSH "
    end
    if flag_data.rst==1
      flags+="RST "
    end
    flags=flags.chop
    return flags
  end
end
class TCPSocket
  def initialize(driver,dst_ip,port)
    @driver=driver
    @src_port=rand(3000..6000)
    @dst_port=port
    @dst_ip=dst_ip
    @driver.connect(@src_port,@dst_port,dst_ip)
  end
  def send(msg)
    @driver.send_packet({:psh=>true,:ack=>true},@dst_port,msg);
  end
end
class TCPServer
  def initialize(driver,ip,port)
    @driver=driver
    @port=port
    @ip=ip
  end
end
class NetLib
  ARP=0x0806
  IP=0x0800
  UDP=17
  TCP=6
  ARP_RESP=2
  ARP_REQ=1
  def self.show_data(data)
    num_bytes=0
    data.each_byte do |byte|
      byte=byte.to_s(16)
      byte=byte.rjust(2,"0")
      byte="0x#{byte} "
      $stdout.print byte
      num_bytes+=1
      if num_bytes>16
        $stdout.puts ""
        num_bytes=0
      end
    end
    if num_bytes>0
      $stdout.puts ""
    end
  end
end

class ArpUtils
  @@log_arp=false
  def self.log_arp=(val)
    @@log_arp=val
  end
  def self.log_arp()
    return @@log_arp
  end
  def self.add_arp_resp(device,ip)
    device.register_callback(NetLib::ARP) do |packet|
      packet=parse_arp_packet(packet)
      if packet[3]==NetLib::ARP_REQ and packet[1]==ip
        hdr=PacketFu::ARPHeader.new()
        puts "ARP request from #{packet[0]} for IP #{packet[1]}" if @@log_arp
        hdr.arp_daddr_mac=packet[0]
        hdr.arp_saddr_mac=device.mac
        hdr.arp_saddr_ip=packet[1]
        hdr.arp_daddr_ip=packet[2]
        hdr.arp_opcode=NetLib::ARP_RESP
        hdr=hdr.to_s
        device.send_packet(hdr,packet[0],2054)
        puts "ARP response about #{packet[1]} from #{device.mac}" if @@log_arp
      end
    end
  end
  def self.send_arp(device,ip)
    hdr=PacketFu::ARPHeader.new()
    hdr.arp_saddr_mac=device.mac
    hdr.arp_daddr_ip=ip
    hdr.arp_opcode=1
    hdr=hdr.to_s
    device.send_packet(hdr,"ff:ff:ff:ff:ff:ff",NetLib::ARP)
  end
  def self.parse_arp_packet(packet)
    packet=packet[1]
    hdr=PacketFu::ARPHeader.new()
    hdr.read(packet)
    dst_ip=hdr.arp_daddr_ip
    src_ip=hdr.arp_saddr_ip
    src_mac=hdr.arp_src_mac_readable
    opcode=hdr.arp_opcode
    return [src_mac,dst_ip,src_ip,opcode]
  end
end
