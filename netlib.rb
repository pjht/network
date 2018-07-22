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
    puts "Frame of type #{packet[2]} from #{packet[0]} to #{packet[1]} with data #{packet[3]}" if @log
    @socks.each { |socket| next if sock==socket; socket.got_packet(packet) }
  end
end

class MyIPSocket
  def initialize(eth_sock,ip)
    @sock=eth_sock
    @ip=ip
    @resolved={}
    eth_sock.register_callback(NetLib::ARP) do |packet|
      packet=ArpUtils::parse_arp_packet(packet)
      self.got_arp_resp(packet[2],packet[0]) if packet[3]==NetLib::ARP_RESP
    end
    eth_sock.register_callback(NetLib::IP) do |packet|
      packet=parse_ip_packet(packet)
      p packet
    end
  end
  def send_packet(msg,to)
    hdr=PacketFu::IPHeader.new
    hdr.ip_saddr=@ip
    hdr.ip_daddr=to
    hdr.ip_proto=21
    packet=hdr.to_s+msg
    if !@resolved[to]
      ArpUtils.send_arp(@sock,to)
      blah=0
      while !@resolved[to]
        blah=1+1
      end
    end
    @sock.send_packet(packet,@resolved[to],NetLib::IP)
  end
  def parse_ip_packet(packet)
    mac_header=PacketFu::EthHeader.new()
    mac_header=mac_header.to_s
    packet=packet[1]
    packet=mac_header+packet
    packet=PacketFu::IPPacket.parse packet
    return packet.payload
  end
  def got_arp_resp(ip,mac)
    @resolved[ip]=mac
  end
end

class NetLib
  ARP=0x0806
  IP=0x0800
  ARP_RESP=2
  ARP_REQ=1
end
class ArpUtils
  def self.add_arp_resp(device,ip)
    device.register_callback(NetLib::ARP) do |packet|
      packet=parse_arp_packet(packet)
      if packet[3]==NetLib::ARP_REQ and packet[1]==ip
        hdr=PacketFu::ARPHeader.new()
        hdr.arp_daddr_mac=packet[0]
        hdr.arp_saddr_mac=device.mac
        hdr.arp_saddr_ip=packet[1]
        hdr.arp_daddr_ip=packet[2]
        hdr.arp_opcode=NetLib::ARP_RESP
        hdr=hdr.to_s
        device.send_packet(hdr,packet[0],2054)
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
