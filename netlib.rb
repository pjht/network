require "logger"
class EtherSocket
  def initialize(cable,mac)
    @mac=mac
    @callbacks=[]
    @cable=cable
    cable.add_device(self)
  end
  def send_packet(data,to)
    @cable.send_packet([@mac,to,0,data],self)
  end
  def register_callback(&block)
    @callbacks.push block
  end
  def got_packet(packet)
    return if packet[1]!=@mac
    @callbacks.each { |cback| cback.call([packet[0],packet[2],packet[3]]) }
  end
end

class EtherCable
  def initialize(lfile=nil)
    @socks=[]
    if lfile
      @log=true
      @logger=Logger.new(File.open(lfile,"w"))
    else
      @log=false
    end
  end
  def add_device(socket)
    @socks.push(socket)
  end
  def send_packet(packet,sock)
    @logger.info "Frame of type #{packet[2]} from #{mac_to_str(packet[0])} to #{mac_to_str(packet[1])} with data #{packet[3]}" if @log
    @socks.each { |socket| next if sock==socket; socket.got_packet(packet) }
  end
  private
  def mac_to_str(mac)
    old=mac.clone
    mac=[]
    old.each do |byte|
      byte=byte.to_i.to_s(16)
      byte=byte.rjust(2,"0")
      mac.push byte
    end
    return "#{mac[0]}:#{mac[1]}:#{mac[2]}:#{mac[3]}:#{mac[4]}:#{mac[5]}"
  end
end
