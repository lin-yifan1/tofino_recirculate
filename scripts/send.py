#!/usr/bin/env python
import argparse

from rec_header import Rec
from scapy.all import IP, Ether, sendp

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('rec_num', type=int, default=0, help='the switch needs to recirculate the packt rec_num times')
    args = parser.parse_args()

    rec_num = args.rec_num

    pkt = Ether() / Rec(rec_num=rec_num) / IP(src="2.2.2.2", dst="3.3.3.3")

    # if (control_bit is not None):
    #     print("sending control packet")
    #     pkt =  Ether()
    #     pkt = pkt / MyController(control_bit=control_bit) / IP(src="{}.{}.{}.{}".format(ip_1, ip_2, ip_3, ip_4)) 
    # else:
    #     print("sending TCP packet")
    #     pkt =  Ether()
    #     pkt = pkt / IP(src="{}.{}.{}.{}".format(ip_1, ip_2, ip_3, ip_4)) / TCP(dport=1234, sport=random.randint(49152,65535)) 

    sendp(pkt, iface="veth4", verbose=False)


if __name__ == '__main__':
    main()
