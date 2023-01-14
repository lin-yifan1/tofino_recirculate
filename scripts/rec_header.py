from scapy.all import *

TYPE_REC = 0x1212
TYPE_IPV4 = 0x0800

class Rec(Packet):
    name = "Rec"
    fields_desc = [
        ShortField("pid", 0),
        ShortField("rec_num", 0)
    ]


bind_layers(Ether, Rec, type=TYPE_REC)
bind_layers(Rec, IP, pid=TYPE_IPV4)

