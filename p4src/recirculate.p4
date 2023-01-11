/* -*- P4_16 -*- */
#include <core.p4>
#if __TARGET_TOFINO__ == 3
#include <t3na.p4>
#elif __TARGET_TOFINO__ == 2
#include <t2na.p4>
#else
#include <tna.p4>
#endif

#include "common/headers.p4"
#include "common/util.p4"

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
**************************************************************************/
const PortId_t rec_port = 68;       // recirculation port
const bit<8> TYPE_REC =  0x17;

/* Table Sizes */
const int IPV4_HOST_SIZE = 65536;

#ifdef USE_ALPM
const int IPV4_LPM_SIZE  = 400*1024;
#else
const int IPV4_LPM_SIZE  = 12288;
#endif

/* Users */

header rec_t {
    bit<16> rec_num; // switch needs to recirculate the packet rec_num times
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
 
    /***********************  H E A D E R S  ************************/

struct my_ingress_headers_t {
    ethernet_h   ethernet;
    ipv4_h       ipv4;
    rec_t        rec;
}

    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct my_ingress_metadata_t {
}

    /***********************  P A R S E R  **************************/
parser IngressParser(packet_in        pkt,
    /* User */    
    out my_ingress_headers_t          hdr,
    out my_ingress_metadata_t         meta,
    /* Intrinsic */
    out ingress_intrinsic_metadata_t  ig_intr_md)
{
    /* This is a mandatory state, required by Tofino Architecture */
    TofinoIngressParser() tofino_parser;

     state start {
        tofino_parser.apply(pkt, ig_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4:  parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            TYPE_REC: parse_rec;
            default: accept;
        }
    }

    state parse_rec {
        pkt.extract(hdr.rec);
        transition accept;
    }
}

    /***************** M A T C H - A C T I O N  *********************/

control Ingress(
    /* User */
    inout my_ingress_headers_t                       hdr,
    inout my_ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md)
{   
    action drop() {
        ig_intr_dprsr_md.drop_ctl = 0x1;
    }

    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
        ig_tm_md.bypass_egress = 1w1;
    }
    
    // Recirculate the packet to the recirculation port
    // Decrease the recirculation number
    // action recirculate(PortId_t recirc_port){
    //     ig_intr_tm_md.ucast_egress_port = recirc_port;
    //     hdr.rec.rec_num = hdr.rec.rec_num - 1;      
    // }

    action recir(PortId_t recirc_port){
        recirculate(recirc_port);
        hdr.rec.rec_num = hdr.rec.rec_num - 1;
    }

    // ipv4 table used to forward packets
    // not used in debug
    table ipv4_host {
        key = { 
            hdr.ipv4.dst_addr : exact;
        }
        actions = {
            send;
            drop;
            @defaultonly NoAction;
        }
        const default_action = NoAction();
        size = IPV4_HOST_SIZE;
    }

    apply {
        if (hdr.ipv4.isValid()) {
            if (hdr.rec.isValid()) {
                if (hdr.rec.rec_num == 0) {
                    send(1);
                } else {
                    recir(rec_port);
                }
            }
        }
    }
}

control IngressDeparser(packet_out pkt,
    /* User */
    inout my_ingress_headers_t                       hdr,
    in    my_ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md)
{
    apply {
        pkt.emit(hdr);
    }
}

/************ F I N A L   P A C K A G E ******************************/
Pipeline(
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EmptyEgressParser(),
    EmptyEgress(),
    EmptyEgressDeparser()
) pipe;

Switch(pipe) main;