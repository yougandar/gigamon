sudo -i

cd ~
mkdir install
cd ./install

# Download needfull sources
wget https://www.snort.org/downloads/snort/daq-2.0.6.tar.gz
wget https://www.snort.org/downloads/snort/snort-2.9.11.1.tar.gz
wget http://downloads.sourceforge.net/project/libdnet/libdnet/libdnet-1.11/libdnet-1.11.tar.gz
wget http://ftp.netfilter.org/pub/libnetfilter_queue/libnetfilter_queue-1.0.2.tar.bz2
wget http://ftp.netfilter.org/pub/libnfnetlink/libnfnetlink-1.0.1.tar.bz2
wget http://www.tcpdump.org/release/libpcap-1.7.4.tar.gz
wget http://ftp.netfilter.org/pub/libmnl/libmnl-1.0.3.tar.bz2

# Install needfull packages
sudo apt-get install flex bison build-essential checkinstall libpcap-dev libnet1-dev libpcre3-dev libmysqlclient15-dev libnetfilter-queue-dev iptables-dev

# Remove old libpcap
sudo apt-get -f remove libpcap-dev libpcap0.8 libpcap0.8-dev libpcap0.8-dev:amd64  libpcap0.8:amd64

# Build/Install libpcap
tar zxvf ./libpcap-1.7.4.tar.gz
cd ./libpcap-1.7.4
./configure
make
checkinstall -y
cd ..

# Build/Install libdnet
tar zxvf ./libdnet-1.11.tar.gz
cd ./libdnet-1.11
./configure "CFLAGS=-fPIC -g -O2"
make
checkinstall -y
ln -s /usr/local/lib/libdnet.1.0.1 /usr/lib/libdnet.1
cd ..

# Build/Install libnfnetlink
tar xvf ./libnfnetlink-1.0.1.tar.bz2
cd ./libnfnetlink-1.0.1
./configure
make
checkinstall -y
cd ..

# Build/Install libmnl
tar xvf ./libmnl-1.0.3.tar.bz2
cd ./libmnl-1.0.3
./configure
make
checkinstall -y
cd ..

# Build/Install libnetfilter_queue
tar xvf ./libnetfilter_queue-1.0.2.tar.bz2
cd ./libnetfilter_queue-1.0.2
./configure
make
checkinstall -y
cd ..

# Build/Install daq
tar zxvf ./daq-2.0.6.tar.gz
cd daq-2.0.6
./configure
make
checkinstall -y
cd ..

# Build/Install snort
tar zxvf ./snort-2.9.11.1.tar.gz
cd ./snort-2.9.11.1
./configure
make
checinstall -y

# Configuration

cp /root/install/snort-2.9.11.1/etc/classification.config /usr/local/etc/snort/classification.config
mkdir /var/log/snort

EDIT vim /usr/local/etc/snort/snort.conf

# 1: Global variable to be used in configuration and rules
var HOME_NET any
var RULE_PATH /usr/local/etc/snort/rules
# 2: Decoder configuration
config disable_decode_alerts
# 3: Detector setup
config pcre_match_limit: 3500
config react: /usr/local/etc/snort/react.html
# 4: Preprocessor setup
# Be carefull: preprocessors will normalize packages on fly, so you cat get unexpected results
preprocessor normalize_ip4
# Preprocessor for fragmented packages
preprocessor frag3_global: max_frags 65536
# State control and session build preprocessors
preprocessor stream5_global: max_tcp 8192, track_tcp yes, track_udp yes, track_icmp no, max_active_responses 2, min_response_seconds 5

preprocessor stream5_tcp: policy windows, detect_anomalies, require_3whs 180, \
   overlap_limit 10, small_segments 3 bytes 150, timeout 180, \
    ports client 21 22 23 25 42 53 79 109 110 111 113 119 135 136 137 139 143 \
        161 445 513 514 587 593 691 1433 1521 2100 3306 6070 6665 6666 6667 6668 6669 \
        7000 8181 32770 32771 32772 32773 32774 32775 32776 32777 32778 32779, \
    ports both 80 81 443
preprocessor stream5_udp: timeout 180

# 6: Enable detailed output libraries
include classification.config
# 7: Load rules
include $RULE_PATH/local.rules

edit /usr/local/etc/snort/react.html

<h1>PAGE_BLOCKED</h1>
Create rules path

mkdir /usr/local/etc/snort/rules
Create /usr/local/etc/snort/rules/local.rules

alert tcp any any -> 95.66.188.25 80 (content:"vladinfo.ru"; nocase; react: msg; sid: 1; rev:1;)
Configure iptables

iptables -t raw -A PREROUTING -i eth1 -p tcp -m tcp --dport 80 -j NFQUEUE --queue-num 1
Run snort

snort -Q --daq nfq --daq-var queue=1 -c /usr/local/etc/snort/snort.conf -D
