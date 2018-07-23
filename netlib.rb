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
  def initialize(log=false)
    @socks=[]
    @log=log
  end
  def add_device(socket)
    @socks.push(socket)
  end
  def send_packet(packet,sock)
    if @log
      puts "Frame of type #{packet[2]} from #{packet[0]} to #{packet[1]}. Data:"
      num_bytes=0
      packet[3].each_byte do |byte|
        byte=byte.to_s(16)
        byte=byte.rjust(2,"0")
        byte="0x#{byte} "
        print byte
        num_bytes+=1
        if num_bytes>16
          puts ""
          num_bytes=0
        end
      end
      if num_bytes>0
        puts ""
      end
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
      self.got_arp_resp(packet[2],packet[0]) if packet[3]==NetLib::ARP_RESP
    end
    eth_sock.register_callback(NetLib::IP) do |packet|
      packet=parse_ip_packet(packet)
      if @log
        $stdout.puts "IP packet of type #{packet[0]} to #{@ip} from #{packet[1]}. Data:"
        num_bytes=0
        packet[2].each_byte do |byte|
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
  def got_arp_resp(ip,mac)
    @resolved[ip]=mac
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
    @callbacks=[]
    driv.register_callback(NetLib::UDP) do |from,data|
      packet=parse_udp_packet(data)
      if @log
        $stdout.puts "UDP datagram from #{from}:#{packet[0]} on port #{packet[1]}. Data:"
        num_bytes=0
        packet[2].each_byte do |byte|
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
      if @callbacks[packet[0]]
        @callbacks[packet[0]].each { |cback| cback.call(from,packet[0],packet[1],packet[2]) }
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

class NetLib
  ARP=0x0806
  IP=0x0800
  UDP=17
  ARP_RESP=2
  ARP_REQ=1
end

class ArpUtils
  @@log_arp=false
  def self.log_arp=(val)
    @@log_arp=val
  end
  def self.log_arp(val)
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
