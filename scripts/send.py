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

    sendp(pkt, iface="veth251", verbose=False)


if __name__ == '__main__':
    main()
